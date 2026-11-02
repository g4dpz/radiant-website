# Requirements Document

## Introduction

The DTN Abstraction Layer is a vendor-neutral configuration and management layer for BPv7 Delay/Disruption Tolerant Networking implementations within the RADIANT project. It provides a unified control plane for generating implementation-specific configuration from a canonical model, managing DTN engine lifecycle, and delivering unified monitoring across multiple backends (ION-DTN, Hardy, and future engines such as ESA-ION).

The abstraction layer is strictly a management and control plane component. It does NOT sit in the data path. Bundle transfer operations (bp_send, bp_receive) and CFDP operations (cfdp_put) are performed by external applications calling native implementation APIs directly. This layer replaces the previous HDTN-specific integration with a backend-neutral design.

The layer uses a three-tier configuration model: a Network Model (nodes, neighbors, contacts, ranges, convergence layers), an Operational Model (routing, policy, security, storage), and a Backend Model (generated ionadmin scripts, Hardy YAML). Operators express intent through a canonical YAML/JSON document, and the abstraction layer generates the backend-specific artifacts automatically.

## Glossary

- **Abstraction_Layer**: The Rust crate providing vendor-neutral configuration generation, lifecycle management, and monitoring for DTN engines
- **Backend_Adapter**: A Rust trait implementation that translates canonical configuration into backend-specific artifacts and commands for a particular DTN engine
- **Adapter_Registry**: The component that manages registration and lookup of available Backend_Adapter implementations
- **Canonical_Model**: The implementation-neutral representation of DTN network configuration expressed in YAML or JSON
- **Network_Model**: The layer of the Canonical_Model describing nodes, neighbors, contact plans, ranges, and convergence layers
- **Operational_Model**: The layer of the Canonical_Model describing routing strategy, policy, and storage parameters
- **Backend_Model**: The generated implementation-specific configuration artifacts (ION .rc files, Hardy YAML)
- **ION_DTN**: NASA JPL Interplanetary Overlay Network DTN implementation using ionadmin scripts (.ionrc, .bprc, .ltprc, .ipnrc)
- **Hardy**: A DTN implementation using YAML-based configuration
- **DTN_Engine**: A running instance of a DTN implementation managed by the Abstraction_Layer
- **Contact_Plan**: A schedule of communication opportunities between DTN nodes specifying time windows and data rates
- **Convergence_Layer**: The transport protocol layer responsible for transmitting bundles over a specific link type (e.g., LTP, TCP, KISS)
- **Endpoint_ID**: A DTN endpoint identifier using either the "dtn" or "ipn" URI scheme (e.g., dtn://g4dpz-1/mail)
- **Node**: A DTN network element identified by an Endpoint_ID and node number
- **Neighbor**: A directly reachable DTN Node connected via one or more Convergence_Layer links
- **CGR**: Contact Graph Routing — the routing algorithm that uses Contact_Plan data to compute forwarding paths
- **BPSec**: Bundle Protocol Security specification — not used over amateur radio links per ITU Radio Regulations; the abstraction layer does not generate BPSec configuration for amateur deployments
- **KISS**: Keep It Simple Stupid — a framing protocol for amateur radio TNC hardware
- **Hot_Reconfiguration**: Applying configuration changes to a running DTN_Engine without requiring a restart
- **Capability_Set**: The set of features a given Backend_Adapter supports, used for graceful feature-difference handling
- **Management_API**: The HTTP/JSON interface exposed by the Abstraction_Layer for external controllers
- **Callsign_EID**: An Endpoint_ID embedding an amateur radio callsign for regulatory station identification compliance

## Requirements

### Requirement 1: Backend Adapter Registration and Selection

**User Story:** As a system integrator, I want to register and select DTN backend adapters, so that I can target different BPv7 implementations without redesigning the configuration model.

#### Acceptance Criteria

1. THE Adapter_Registry SHALL provide a registration function that accepts an adapter name string and a Backend_Adapter trait implementation
2. THE Adapter_Registry SHALL provide a lookup function that accepts an adapter name string and returns the corresponding Backend_Adapter trait implementation
3. IF a caller registers an adapter with a name that is already registered, THEN THE Adapter_Registry SHALL return an error indicating duplicate registration
4. IF a caller requests an adapter with a name that is not registered, THEN THE Adapter_Registry SHALL return an error indicating the adapter is not found
5. THE Adapter_Registry SHALL be safe for concurrent access from multiple threads
6. THE Abstraction_Layer SHALL provide Backend_Adapter implementations for ION_DTN and Hardy at initial release

### Requirement 2: Node Definition and Identity

**User Story:** As a network designer, I want to define DTN nodes with their identity and services through a common model, so that node configuration is independent of the backend.

#### Acceptance Criteria

1. THE Canonical_Model SHALL represent a Node with a unique node number, an Endpoint_ID, a human-readable name, and a list of service demux tokens
2. THE Canonical_Model SHALL support Endpoint_ID values using both the "dtn" URI scheme and the "ipn" URI scheme
3. THE Canonical_Model SHALL support Callsign_EID values in the format dtn://callsign-ssid/service for amateur radio regulatory compliance
4. WHEN a Node definition omits the Endpoint_ID, THE Abstraction_Layer SHALL derive a default Endpoint_ID from the node number using the ipn scheme
5. IF a Node definition contains a duplicate node number within the same configuration, THEN THE Abstraction_Layer SHALL return a validation error identifying the conflict

### Requirement 3: Neighbor Abstraction

**User Story:** As a network designer, I want to define neighbors with protocol and address information through a common model, so that the backend generates the required induct/outduct/span configuration automatically.

#### Acceptance Criteria

1. THE Canonical_Model SHALL represent a Neighbor with a reference to a remote Node, one or more Convergence_Layer link definitions, and optional rate limits
2. WHEN a Neighbor definition is provided, THE Backend_Adapter SHALL generate the required induct and outduct configuration for the target backend
3. THE Canonical_Model SHALL support specifying the KISS convergence layer with TNC device path, baud rate, and LTP engine identifiers for amateur radio TNC hardware
4. IF a Neighbor references a Node that is not defined in the current configuration, THEN THE Abstraction_Layer SHALL return a validation error identifying the unresolved reference

### Requirement 4: Contact Plan Management

**User Story:** As a network operator, I want to manage contact plans through a unified model, so that CGR has accurate topology information regardless of the backend.

#### Acceptance Criteria

1. THE Canonical_Model SHALL represent a Contact with source node, destination node, start time, end time, data rate in bits per second, and confidence value
2. THE Canonical_Model SHALL represent a Range with source node, destination node, and one-way light time in seconds
3. WHEN a Contact_Plan is provided to the Backend_Adapter, THE Backend_Adapter SHALL generate the backend-specific contact plan representation (ionadmin contact commands for ION_DTN, contact plan configuration for Hardy)
4. THE Abstraction_Layer SHALL validate that all node references within a Contact_Plan correspond to defined Nodes
5. IF a Contact definition has a start time greater than or equal to the end time, THEN THE Abstraction_Layer SHALL return a validation error

### Requirement 5: Convergence Layer Configuration

**User Story:** As a network designer, I want to configure convergence layer parameters through the canonical model, so that transport settings are expressed backend-neutrally.

#### Acceptance Criteria

1. THE Canonical_Model SHALL support configuration of LTP convergence layer parameters including MTU size, segment rate, and LTP engine identifiers
2. THE Canonical_Model SHALL support configuration of TCP convergence layer (TCPCLv4) parameters including bind address, port, and keepalive interval
3. THE Canonical_Model SHALL support configuration of KISS convergence layer parameters including TNC device path, baud rate, and frame size for amateur radio hardware
4. THE Canonical_Model SHALL support configuration of UDP convergence layer parameters including bind address and port
5. WHEN convergence layer parameters are provided, THE Backend_Adapter SHALL map the canonical parameters to the backend-specific configuration fields

### Requirement 6: Routing Configuration

**User Story:** As a network operator, I want to configure routing strategy through the abstraction layer, so that I can select between CGR, static, or default routing without backend-specific knowledge.

#### Acceptance Criteria

1. THE Operational_Model SHALL support specifying the routing strategy as one of: CGR, static, or default
2. WHEN the routing strategy is set to CGR, THE Backend_Adapter SHALL generate the backend-specific configuration to enable Contact Graph Routing with the associated Contact_Plan
3. WHEN the routing strategy is set to static, THE Operational_Model SHALL accept a list of static route entries mapping destination nodes to next-hop neighbors
4. THE Backend_Adapter SHALL translate the canonical routing configuration into the backend-specific routing commands or configuration fields

### Requirement 7: Configuration Document Serialization

**User Story:** As a DevOps engineer, I want to express the entire DTN configuration as a YAML or JSON document, so that I can version-control it and deploy across environments.

#### Acceptance Criteria

1. THE Abstraction_Layer SHALL serialize the complete Canonical_Model to YAML format
2. THE Abstraction_Layer SHALL serialize the complete Canonical_Model to JSON format
3. THE Abstraction_Layer SHALL deserialize a YAML document into a validated Canonical_Model
4. THE Abstraction_Layer SHALL deserialize a JSON document into a validated Canonical_Model
5. FOR ALL valid Canonical_Model values, serializing to YAML then deserializing SHALL produce an equivalent Canonical_Model (round-trip property)
6. FOR ALL valid Canonical_Model values, serializing to JSON then deserializing SHALL produce an equivalent Canonical_Model (round-trip property)
7. IF a configuration document contains invalid or malformed content, THEN THE Abstraction_Layer SHALL return a descriptive error identifying the location and nature of the problem

### Requirement 8: Backend Configuration Generation

**User Story:** As a system integrator, I want the abstraction layer to automatically generate backend-specific configuration from the canonical model, so that I never write ionadmin scripts or Hardy configs manually.

#### Acceptance Criteria

1. WHEN the ION_DTN Backend_Adapter generates configuration, THE Adapter SHALL produce .ionrc, .bprc, .ltprc, and .ipnrc files matching ionadmin script syntax
2. WHEN the Hardy Backend_Adapter generates configuration, THE Adapter SHALL produce a valid Hardy YAML configuration file
3. THE Abstraction_Layer SHALL provide a preview function that returns generated backend configuration without deploying it
4. THE Abstraction_Layer SHALL validate the Canonical_Model for completeness and consistency before generating backend configuration
5. IF the Canonical_Model references capabilities not supported by the selected Backend_Adapter, THEN THE Abstraction_Layer SHALL return an error identifying the unsupported features

### Requirement 9: DTN Engine Lifecycle Management

**User Story:** As a system operator, I want to start and stop DTN engines through the abstraction layer, so that I manage lifecycle without implementation-specific daemon commands.

#### Acceptance Criteria

1. THE Backend_Adapter SHALL provide a start operation that launches the DTN_Engine using the generated backend configuration
2. THE Backend_Adapter SHALL provide a stop operation that gracefully terminates the DTN_Engine
3. THE Backend_Adapter SHALL provide a restart operation that stops and then starts the DTN_Engine
4. THE Abstraction_Layer SHALL define engine states: Stopped, Starting, Running, Stopping, and Failed
5. WHEN a start operation completes successfully, THE Abstraction_Layer SHALL transition the engine state to Running
6. WHEN a DTN_Engine process exits unexpectedly, THE Abstraction_Layer SHALL transition the engine state to Failed and record the failure reason
7. THE Backend_Adapter SHALL provide a version query operation that returns the installed DTN_Engine version string
8. THE Backend_Adapter SHALL provide a health check operation that returns the operational status of the DTN_Engine

### Requirement 10: Runtime Hot Reconfiguration

**User Story:** As a network operator, I want to perform administrative operations at runtime without restarting nodes, so that I can adapt to changing network conditions.

#### Acceptance Criteria

1. THE Backend_Adapter SHALL provide an add-contact operation that inserts a new contact into the running DTN_Engine without restart
2. THE Backend_Adapter SHALL provide a remove-contact operation that removes an existing contact from the running DTN_Engine without restart
3. THE Backend_Adapter SHALL provide an add-neighbor operation that adds a new neighbor to the running DTN_Engine without restart
4. THE Backend_Adapter SHALL provide a remove-neighbor operation that removes an existing neighbor from the running DTN_Engine without restart
5. THE Backend_Adapter SHALL provide an enable-link operation that activates a specific Convergence_Layer link on the running DTN_Engine
6. THE Backend_Adapter SHALL provide a disable-link operation that deactivates a specific Convergence_Layer link on the running DTN_Engine
7. IF a Backend_Adapter does not support a specific Hot_Reconfiguration operation, THEN THE Abstraction_Layer SHALL return an error indicating the operation is unsupported by the current backend

### Requirement 11: Status and Statistics Reporting

**User Story:** As an operator, I want to query node status and bundle statistics, so that I can monitor DTN operations without implementation-specific tools.

#### Acceptance Criteria

1. THE Abstraction_Layer SHALL report bundle statistics including counts of bundles sourced, forwarded, delivered, expired, and currently queued
2. THE Abstraction_Layer SHALL report link state per neighbor including active/inactive status and byte counts sent and received
3. THE Backend_Adapter SHALL translate backend-specific telemetry data into the common statistics model
4. WHEN statistics are queried, THE Abstraction_Layer SHALL return the most recent data available from the DTN_Engine

### Requirement 12: Event Notification

**User Story:** As a monitoring system, I want to subscribe to operational events, so that I can react to link state changes, contact plan updates, and engine state transitions.

#### Acceptance Criteria

1. THE Abstraction_Layer SHALL support event subscriptions for link-state-change events indicating when a neighbor link becomes active or inactive
2. THE Abstraction_Layer SHALL support event subscriptions for contact-plan-change events indicating when contacts are added or removed
3. THE Abstraction_Layer SHALL support event subscriptions for engine-state-change events indicating transitions between Stopped, Starting, Running, Stopping, and Failed states
4. WHEN a subscribed event occurs, THE Abstraction_Layer SHALL deliver a notification containing the event type, timestamp, and relevant details to all active subscribers
5. THE Abstraction_Layer SHALL support multiple concurrent subscribers for the same event type

### Requirement 13: Backend Capability Discovery

**User Story:** As an integrator, I want to query which capabilities a given backend supports, so that I can handle feature differences gracefully.

#### Acceptance Criteria

1. THE Backend_Adapter SHALL expose a Capability_Set describing which operations the adapter supports
2. THE Capability_Set SHALL indicate support or non-support for each Hot_Reconfiguration operation (add-contact, remove-contact, add-neighbor, remove-neighbor, enable-link, disable-link)
3. THE Capability_Set SHALL indicate which Convergence_Layer types the backend supports
4. THE Capability_Set SHALL indicate which routing strategies the backend supports
5. WHEN a caller queries capabilities, THE Abstraction_Layer SHALL return the Capability_Set without requiring the DTN_Engine to be running

### Requirement 14: Unified Error Reporting

**User Story:** As a developer, I want consistent error reporting across all backends, so that I can handle failures uniformly regardless of which backend produced them.

#### Acceptance Criteria

1. THE Abstraction_Layer SHALL define a common error type that includes an error category, a human-readable message, and an optional backend-specific error code
2. THE Abstraction_Layer SHALL define error categories including: ValidationError, ConfigurationError, LifecycleError, RuntimeError, UnsupportedOperation, and CommunicationError
3. WHEN a Backend_Adapter encounters a backend-specific error, THE Adapter SHALL map the error to the common error type preserving the original error information
4. THE Abstraction_Layer SHALL include sufficient context in error messages to identify the failing operation, the affected resource, and the backend that produced the error

### Requirement 15: HTTP/JSON Management API

**User Story:** As a controller application, I want to interact with the abstraction layer through HTTP/JSON, so that I can manage DTN nodes using standard tooling including curl.

#### Acceptance Criteria

1. THE Management_API SHALL expose HTTP endpoints for all configuration, lifecycle, runtime administration, monitoring, and capability discovery operations
2. THE Management_API SHALL accept and return JSON request and response bodies
3. THE Management_API SHALL conform to an OpenAPI specification document
4. THE Management_API SHALL return appropriate HTTP status codes: 200 for success, 400 for validation errors, 404 for not-found resources, 409 for conflict errors, and 500 for internal errors
5. THE Management_API SHALL include structured error responses matching the common error type defined in Requirement 14
6. THE Management_API SHALL support event subscription via Server-Sent Events for the notifications defined in Requirement 12
