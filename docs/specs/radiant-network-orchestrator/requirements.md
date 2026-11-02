# Requirements Document

## Introduction

The RADIANT Network Orchestrator is the highest-level coordination component in the RADIANT architecture, sitting above the DTN Abstraction Layer and Contact Plan as a Service (CPaaS). It transforms RADIANT from a collection of independent DTN nodes into a coordinated platform for managing delay-tolerant network operations.

The Orchestrator provides a unified control plane that integrates network topology discovery, policy-based traffic management, path computation, security and trust services, and operational monitoring. Applications express high-level delivery requirements (destination, priority, delivery confidence) and the Orchestrator determines the optimal path and resource allocation, drawing from the GSaaS model where users request communication opportunities rather than access to specific infrastructure.

This component builds upon the DTN Abstraction Layer's `Engine` interface and common data models, and the CPaaS service's contact plan management, conflict resolution, and plan distribution capabilities. The Orchestrator consumes contact plans from CPaaS, topology information from registered nodes, and policy configuration from operators to make routing and resource allocation decisions.

## Glossary

- **Orchestrator**: The Go service providing network-wide coordination of DTN operations, topology management, policy enforcement, and path computation
- **Topology_Manager**: The component within the Orchestrator responsible for discovering, storing, and maintaining the network graph of nodes and links
- **Policy_Engine**: The component that evaluates traffic classification rules, service class assignments, and resource allocation policies
- **Path_Computer**: The component that computes optimal bundle routing paths using contact plans, topology state, and policy constraints
- **Trust_Manager**: The component managing node authentication, trust relationships, and security policy enforcement
- **Telemetry_Collector**: The component that aggregates monitoring data, link performance metrics, and delivery statistics from network nodes
- **Delivery_Request**: A high-level application request specifying destination, priority, delivery confidence, and optional constraints, submitted to the Orchestrator for fulfillment
- **Service_Class**: A named traffic category (Expedited, Standard, Bulk) with associated priority, bandwidth allocation, and delivery guarantees
- **Network_Graph**: A directed graph representing the current network topology where vertices are nodes and edges are links with associated contact schedules
- **Link**: A directed communication path between two nodes, characterised by data rate, latency, availability schedule, and current state
- **Link_State**: The operational condition of a Link at a given time: Active, Scheduled, Degraded, or Unavailable
- **Relay_Path**: An ordered sequence of nodes and links forming a multi-hop route from source to destination
- **Trust_Level**: A classification of a node's trust status: Trusted, Provisional, Untrusted, or Revoked
- **Node_Identity**: A cryptographic identity binding a NodeID to a public key, used for authentication and trust establishment
- **Delivery_Report**: A record of a completed or failed delivery attempt including path taken, hops traversed, latency, and outcome
- **QoS_Requirement**: A set of quality-of-service parameters (maximum latency, minimum delivery confidence, maximum hop count) associated with a Delivery_Request
- **DTN_Abstraction_Layer**: The existing RADIANT component providing a common `Engine` interface to multiple DTN implementations
- **CPaaS_Service**: The existing RADIANT Contact Plan as a Service providing centralized contact management and distribution
- **Contact_Plan**: An ordered collection of contacts representing scheduled communication opportunities, managed by CPaaS_Service
- **Node**: A DTN endpoint registered in the CPaaS Node_Registry, identified by NodeID and Endpoint_ID
- **Bundle**: A BPv7 protocol data unit as defined in the DTN Abstraction Layer's common data model

## Requirements

### Requirement 1: Network Topology Discovery

**User Story:** As a network operator, I want the Orchestrator to automatically discover and maintain a graph of all DTN nodes and their interconnections, so that routing decisions reflect the current network structure.

#### Acceptance Criteria

1. THE Topology_Manager SHALL maintain a Network_Graph containing all nodes registered in the CPaaS Node_Registry and all links derived from active and scheduled contacts
2. WHEN a new node is registered in the CPaaS Node_Registry, THE Topology_Manager SHALL add the node as a vertex in the Network_Graph within 10 seconds
3. WHEN a node is removed from the CPaaS Node_Registry, THE Topology_Manager SHALL remove the corresponding vertex and all associated edges from the Network_Graph
4. WHEN a new Contact is created in CPaaS_Service, THE Topology_Manager SHALL create or update the corresponding Link edge in the Network_Graph with the contact's data rate, start time, end time, and link characteristics
5. THE Topology_Manager SHALL compute and store reachability information indicating which nodes can reach which other nodes through one or more relay hops
6. WHEN the Network_Graph changes, THE Topology_Manager SHALL recompute reachability information within 5 seconds

### Requirement 2: Network Topology API

**User Story:** As a network operator, I want to query the network topology through an API, so that I can visualise the network and understand connectivity.

#### Acceptance Criteria

1. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/topology/nodes` that returns all nodes in the Network_Graph with their properties and current link states
2. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/topology/links` that returns all links in the Network_Graph with their current Link_State, data rate, and associated contact schedule
3. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/topology/graph` that returns the complete Network_Graph serialized as a JSON adjacency list with node and edge properties
4. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/topology/reachability/{nodeID}` that returns all nodes reachable from the specified node, including the minimum hop count and earliest availability time for each
5. WHEN the links query includes a `state` parameter, THE Orchestrator SHALL filter results to return only links matching the specified Link_State
6. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/topology/paths/{sourceNodeID}/{destNodeID}` that returns all viable Relay_Paths between two nodes within a specified time window

### Requirement 3: Link State Tracking

**User Story:** As a network operator, I want the Orchestrator to track the real-time state of each network link, so that routing decisions account for current link conditions.

#### Acceptance Criteria

1. THE Topology_Manager SHALL maintain a Link_State for each link in the Network_Graph, updated based on contact schedules and telemetry data
2. WHEN the current time falls within a contact's time window, THE Topology_Manager SHALL set the corresponding link's Link_State to Active
3. WHEN a contact's time window has not yet started, THE Topology_Manager SHALL set the corresponding link's Link_State to Scheduled
4. WHEN telemetry indicates a link's bit error rate exceeds the configured degradation threshold, THE Topology_Manager SHALL set the link's Link_State to Degraded
5. WHEN a contact's time window has expired and no future contacts exist for that link within the configured lookahead period, THE Topology_Manager SHALL set the link's Link_State to Unavailable
6. WHEN a Link_State changes, THE Topology_Manager SHALL emit a state change event containing the link identifier, previous state, new state, and timestamp

### Requirement 4: Service Class Definition

**User Story:** As a network operator, I want to define service classes with associated priority levels and resource allocations, so that traffic can be differentiated based on operational importance.

#### Acceptance Criteria

1. THE Policy_Engine SHALL support three default Service_Classes: Expedited (priority 1, minimum 30% bandwidth allocation), Standard (priority 2, minimum 20% bandwidth allocation), and Bulk (priority 3, uses remaining bandwidth)
2. THE Orchestrator SHALL expose a REST endpoint `POST /api/v1/policies/service-classes` that creates a custom Service_Class with fields: name, priority level (positive integer, lower is higher priority), minimum bandwidth percentage, maximum latency tolerance (seconds), and minimum delivery confidence
3. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/policies/service-classes` that returns all configured Service_Classes sorted by priority level
4. THE Orchestrator SHALL expose a REST endpoint `PUT /api/v1/policies/service-classes/{className}` that updates a Service_Class's parameters
5. THE Policy_Engine SHALL enforce that the sum of minimum bandwidth allocations across all Service_Classes does not exceed 100%
6. IF a Service_Class creation or update would cause total minimum bandwidth allocation to exceed 100%, THEN THE Policy_Engine SHALL return an error indicating the allocation conflict

### Requirement 5: Traffic Classification Policy

**User Story:** As a network operator, I want to define rules that classify traffic into service classes based on source, destination, and application attributes, so that the network automatically applies appropriate QoS treatment.

#### Acceptance Criteria

1. THE Policy_Engine SHALL support classification rules containing: rule name, priority (evaluation order), match criteria (source node pattern, destination node pattern, application identifier), and assigned Service_Class
2. THE Orchestrator SHALL expose a REST endpoint `POST /api/v1/policies/classification-rules` that creates a new classification rule
3. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/policies/classification-rules` that returns all classification rules sorted by priority
4. WHEN a Delivery_Request is submitted without an explicit Service_Class, THE Policy_Engine SHALL evaluate classification rules in priority order and assign the first matching Service_Class
5. IF no classification rule matches a Delivery_Request, THEN THE Policy_Engine SHALL assign the Standard Service_Class
6. THE Policy_Engine SHALL support wildcard patterns in source and destination node match criteria using glob syntax

### Requirement 6: Delivery Request API

**User Story:** As an application developer, I want to submit high-level delivery requests specifying destination and quality requirements, so that the Orchestrator handles routing and resource allocation without application-level path management.

#### Acceptance Criteria

1. THE Orchestrator SHALL expose a REST endpoint `POST /api/v1/delivery-requests` that accepts a Delivery_Request containing: source Endpoint_ID, destination Endpoint_ID, payload reference (bundle identifier or inline payload), QoS_Requirement (maximum latency seconds, minimum delivery confidence, maximum hop count), and optional Service_Class override
2. WHEN a Delivery_Request is submitted, THE Orchestrator SHALL validate that both source and destination nodes exist in the Network_Graph
3. WHEN a Delivery_Request is submitted, THE Orchestrator SHALL compute a Relay_Path satisfying the QoS_Requirement using the Path_Computer
4. WHEN a valid Relay_Path is computed, THE Orchestrator SHALL instruct the DTN Abstraction Layer to send the bundle along the computed path by invoking `SendBundle` on the appropriate Engine adapter
5. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/delivery-requests/{requestID}` that returns the current status of a Delivery_Request including: state (Accepted, Routing, In_Transit, Delivered, Failed), computed path, and progress through relay hops
6. IF the Path_Computer cannot find a path satisfying the QoS_Requirement, THEN THE Orchestrator SHALL return the Delivery_Request with state Failed and a reason indicating which constraint could not be satisfied
7. THE Orchestrator SHALL assign a unique request identifier (UUID v4) to each Delivery_Request upon submission

### Requirement 7: Path Computation

**User Story:** As a network operator, I want the Orchestrator to compute optimal paths through the DTN network using contact plans and topology state, so that bundles are routed efficiently considering delay-tolerant constraints.

#### Acceptance Criteria

1. THE Path_Computer SHALL compute Relay_Paths using Contact Graph Routing (CGR) principles: evaluating contacts as time-varying edges and selecting paths that minimise delivery time while respecting capacity constraints
2. WHEN computing a path, THE Path_Computer SHALL consider only links with Link_State of Active or Scheduled
3. WHEN computing a path, THE Path_Computer SHALL respect the QoS_Requirement constraints: excluding paths exceeding maximum latency, paths with delivery confidence below the minimum, and paths exceeding maximum hop count
4. THE Path_Computer SHALL compute delivery confidence for a path as the product of individual link confidence values (from CPaaS Contact Confidence_Level)
5. WHEN multiple valid paths exist, THE Path_Computer SHALL select the path with the earliest expected delivery time
6. THE Path_Computer SHALL support computing alternative paths (up to 3) for redundant forwarding when the Service_Class is Expedited
7. WHEN the Network_Graph or Contact_Plan changes, THE Path_Computer SHALL invalidate cached paths affected by the change

### Requirement 8: Node Authentication

**User Story:** As a network operator, I want nodes to authenticate with the Orchestrator using cryptographic identities, so that only verified nodes can participate in the network.

#### Acceptance Criteria

1. THE Trust_Manager SHALL maintain a Node_Identity record for each node containing: NodeID, public key (Ed25519), identity certificate, registration timestamp, and Trust_Level
2. THE Orchestrator SHALL expose a REST endpoint `POST /api/v1/security/nodes/{nodeID}/register` that accepts a public key and issues a signed identity certificate binding the NodeID to the key
3. WHEN a node communicates with the Orchestrator, THE Trust_Manager SHALL verify the request signature against the node's registered public key
4. IF signature verification fails, THEN THE Trust_Manager SHALL reject the request with HTTP 401 and log the authentication failure with the source NodeID and timestamp
5. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/security/nodes/{nodeID}/identity` that returns the node's public identity information (public key, certificate, Trust_Level, registration date)
6. THE Trust_Manager SHALL support certificate expiry with a configurable validity period, defaulting to 365 days

### Requirement 9: Trust Relationship Management

**User Story:** As a network operator, I want to manage trust relationships between nodes, so that the Orchestrator can enforce security policies about which nodes may relay traffic for others.

#### Acceptance Criteria

1. THE Trust_Manager SHALL assign one of four Trust_Levels to each node: Trusted (full relay and origination privileges), Provisional (limited relay, monitored), Untrusted (receive-only, no relay), or Revoked (no network participation)
2. THE Orchestrator SHALL expose a REST endpoint `PUT /api/v1/security/nodes/{nodeID}/trust-level` that updates a node's Trust_Level
3. WHEN a node's Trust_Level is set to Revoked, THE Trust_Manager SHALL immediately notify the Topology_Manager to remove all links involving that node from path computation
4. THE Path_Computer SHALL exclude nodes with Trust_Level of Untrusted or Revoked from relay positions in computed paths
5. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/security/trust-relationships` that returns all node trust levels with optional filtering by Trust_Level
6. WHEN a node's Trust_Level changes, THE Trust_Manager SHALL log the change with the previous level, new level, operator identity, and reason

### Requirement 10: Telemetry Collection

**User Story:** As a network operator, I want the Orchestrator to collect performance telemetry from network nodes, so that I can monitor network health and the Orchestrator can make informed routing decisions.

#### Acceptance Criteria

1. THE Telemetry_Collector SHALL accept telemetry reports from nodes via a REST endpoint `POST /api/v1/telemetry/reports` containing: reporting NodeID, timestamp, link metrics (per-link: bytes sent, bytes received, bundles sent, bundles received, bit error rate, average latency), and node metrics (storage utilisation percentage, CPU utilisation percentage, uptime seconds)
2. THE Telemetry_Collector SHALL store telemetry data with a configurable retention period defaulting to 30 days
3. THE Telemetry_Collector SHALL compute rolling averages for link metrics over 1-hour, 24-hour, and 7-day windows
4. WHEN a node fails to submit a telemetry report within the configured reporting interval (default 5 minutes for ground nodes, next-contact for space nodes), THE Telemetry_Collector SHALL mark the node as unreachable in the Network_Graph
5. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/telemetry/nodes/{nodeID}` that returns the latest telemetry data and rolling averages for a specific node
6. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/telemetry/links/{linkID}` that returns performance history for a specific link

### Requirement 11: Delivery Statistics

**User Story:** As a network operator, I want to track delivery outcomes and network utilisation statistics, so that I can assess network performance and identify bottlenecks.

#### Acceptance Criteria

1. THE Orchestrator SHALL generate a Delivery_Report for each completed or failed Delivery_Request containing: request identifier, source node, destination node, path taken (ordered list of hops), total latency (seconds), bundle size (bytes), Service_Class, and outcome (Delivered, Failed, Expired)
2. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/statistics/deliveries` that returns delivery statistics with query parameters: from_time, to_time, source_node, dest_node, service_class, and outcome
3. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/statistics/summary` that returns aggregate metrics: total deliveries attempted, delivery success rate (percentage), average delivery latency (seconds), total bytes transferred, and per-Service_Class breakdown
4. THE Orchestrator SHALL compute network utilisation as the ratio of actual data transferred to total available capacity across all active links, reported as a percentage
5. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/statistics/utilisation` that returns per-link and aggregate network utilisation for a specified time window

### Requirement 12: DTN Abstraction Layer Integration

**User Story:** As a RADIANT developer, I want the Orchestrator to integrate with the DTN Abstraction Layer's Engine interface, so that routing decisions are executed through the common DTN interface regardless of the underlying implementation.

#### Acceptance Criteria

1. THE Orchestrator SHALL use the DTN Abstraction Layer's `Engine` interface to send bundles, invoking `SendBundle` with the Bundle struct populated from the Delivery_Request
2. THE Orchestrator SHALL use the DTN Abstraction Layer's `Engine.Health` method to supplement telemetry data with engine-level health information
3. THE Orchestrator SHALL subscribe to DTN Abstraction Layer engine lifecycle events via `OnStateChange` and update the Network_Graph when an engine transitions to Failed state
4. WHEN an Engine adapter reports Failed state, THE Orchestrator SHALL mark all links served by that engine as Unavailable and recompute affected in-transit delivery paths
5. THE Orchestrator SHALL use the DTN Abstraction Layer's `Engine.RegisterEndpoint` method to register the orchestrator's control endpoint (`dtn://orchestrator/control`) on startup
6. THE Orchestrator SHALL use the DTN Abstraction Layer's `Engine.BundleStatus` method to track in-transit bundle progress for active Delivery_Requests

### Requirement 13: CPaaS Integration

**User Story:** As a RADIANT developer, I want the Orchestrator to consume contact plans from CPaaS and react to plan updates, so that path computation always uses current contact schedule information.

#### Acceptance Criteria

1. THE Orchestrator SHALL subscribe to CPaaS plan update notifications for all registered nodes using the CPaaS Subscription mechanism
2. WHEN a CPaaS plan notification is received, THE Orchestrator SHALL retrieve the updated Contact_Plan and refresh the corresponding links in the Network_Graph
3. THE Orchestrator SHALL query CPaaS `GET /api/v1/contacts` with time range parameters to obtain contacts relevant to pending Delivery_Requests
4. THE Orchestrator SHALL use CPaaS Plan_Version to detect stale topology data and trigger a full refresh when a version gap is detected (current version more than 5 behind latest)
5. WHEN the Orchestrator starts, THE Orchestrator SHALL perform a full synchronisation with CPaaS by retrieving all node plans and building the initial Network_Graph
6. THE Orchestrator SHALL use CPaaS Contact Confidence_Level values as link reliability inputs for path computation

### Requirement 14: Network Visualisation Data

**User Story:** As a network operator, I want the Orchestrator to provide structured data suitable for network visualisation, so that I can render real-time network maps in a dashboard.

#### Acceptance Criteria

1. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/visualisation/state` that returns a snapshot containing: all nodes with positions (latitude, longitude, altitude for ground/space nodes), all links with current Link_State and utilisation percentage, and active Delivery_Requests with current hop position
2. THE Orchestrator SHALL expose a WebSocket endpoint `ws /api/v1/visualisation/stream` that pushes incremental state updates (node additions/removals, link state changes, delivery progress) to connected clients
3. WHEN a Link_State changes, THE Orchestrator SHALL push an update event on the visualisation stream within 2 seconds
4. THE visualisation state response SHALL include a timestamp and a monotonically increasing sequence number for client-side ordering
5. THE Orchestrator SHALL support filtering the visualisation stream by geographic region (bounding box) or by node type

### Requirement 15: Orchestrator Configuration

**User Story:** As a RADIANT operator, I want to configure the Orchestrator via a YAML configuration file, so that I can customise behaviour without code changes.

#### Acceptance Criteria

1. THE Orchestrator SHALL support a YAML configuration file specifying: listen address and port, CPaaS service URL, DTN Abstraction Layer engine name, database file path, telemetry retention period, reporting intervals, and log level
2. THE Orchestrator SHALL support configuration of path computation parameters: maximum path computation time (milliseconds), maximum alternative paths, default lookahead period (hours), and link degradation threshold (bit error rate)
3. THE Orchestrator SHALL support configuration of security parameters: certificate validity period (days), authentication enabled flag, and trust policy (open or strict)
4. THE Orchestrator SHALL validate all configuration values at load time and return descriptive errors for invalid entries
5. IF a required configuration value is missing, THEN THE Orchestrator SHALL return an error at startup identifying the missing field
6. THE Orchestrator SHALL support environment variable overrides for all configuration values using the prefix `RADIANT_ORCHESTRATOR_`

### Requirement 16: Orchestrator Health and Metrics

**User Story:** As a RADIANT operator, I want to monitor the Orchestrator's own health and operational metrics, so that I can detect issues with the coordination layer itself.

#### Acceptance Criteria

1. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/health` that returns: service status (healthy, degraded, unhealthy), uptime, CPaaS connectivity state, DTN engine connectivity state, and database connectivity state
2. THE Orchestrator SHALL expose a REST endpoint `GET /api/v1/metrics` that returns: total nodes in topology, total active links, pending delivery requests, completed deliveries in the last hour, average path computation time (milliseconds), and telemetry reports received in the last hour
3. WHEN connectivity to CPaaS_Service is lost, THE Orchestrator SHALL report degraded status and continue operating with cached topology data
4. WHEN connectivity to the DTN Abstraction Layer engine is lost, THE Orchestrator SHALL report degraded status and queue delivery requests for retry when connectivity is restored
5. THE Orchestrator SHALL log all delivery request submissions, path computations, and trust level changes with timestamps for audit purposes

### Requirement 17: Persistence and Recovery

**User Story:** As a RADIANT operator, I want the Orchestrator to persist its state durably, so that it recovers topology, policies, and pending requests after a restart.

#### Acceptance Criteria

1. THE Orchestrator SHALL persist network topology, policy configurations, trust relationships, pending delivery requests, and delivery reports to a SQLite database
2. WHEN the Orchestrator starts, THE Orchestrator SHALL load persisted state from the database and resume operations within 10 seconds for databases containing up to 10,000 nodes and 100,000 delivery reports
3. THE Orchestrator SHALL use database transactions for all write operations to ensure atomicity
4. IF a write transaction fails, THEN THE Orchestrator SHALL return an error to the caller without partial state changes
5. THE Orchestrator SHALL support a configurable database file path via the configuration file

### Requirement 18: Delivery Request Serialization

**User Story:** As a RADIANT developer, I want to serialize and deserialize Delivery_Requests and Delivery_Reports, so that they can be stored, transmitted between components, and logged consistently.

#### Acceptance Criteria

1. THE Orchestrator SHALL provide a `MarshalDeliveryRequest` function that serializes a Delivery_Request to a JSON byte slice
2. THE Orchestrator SHALL provide an `UnmarshalDeliveryRequest` function that deserializes a JSON byte slice into a Delivery_Request
3. FOR ALL valid Delivery_Request values, marshalling then unmarshalling SHALL produce an equivalent Delivery_Request (round-trip property)
4. THE Orchestrator SHALL provide a `MarshalDeliveryReport` function that serializes a Delivery_Report to a JSON byte slice
5. THE Orchestrator SHALL provide an `UnmarshalDeliveryReport` function that deserializes a JSON byte slice into a Delivery_Report
6. FOR ALL valid Delivery_Report values, marshalling then unmarshalling SHALL produce an equivalent Delivery_Report (round-trip property)
7. IF `UnmarshalDeliveryRequest` or `UnmarshalDeliveryReport` receives malformed input, THEN THE Orchestrator SHALL return a descriptive error identifying the parse failure
