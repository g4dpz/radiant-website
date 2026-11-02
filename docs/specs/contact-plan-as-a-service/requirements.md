# Requirements Document

## Introduction

Contact Plan as a Service (CPaaS) extends the RADIANT project by treating contact plan information as a shared network resource managed independently of any DTN implementation. Rather than each DTN engine maintaining its own contact plan, CPaaS provides a centralized service that acts as the authoritative source for network connectivity opportunities. The service ingests contact information from multiple sources (manual entry, orbital prediction engines, scheduled link agreements), stores it in a canonical data model, and distributes engine-specific contact plans to subscribed DTN nodes via the DTN Abstraction Layer.

This decoupling enables multiple DTN engines (HDTN, ION-DTN, ESA DTN) to share a common view of network opportunities, supports dynamic updates as orbital predictions are refined or new links are scheduled, and provides conflict resolution when contacts overlap or change. The architecture draws lessons from Ground Station as a Service (GSaaS) platforms where users request communication opportunities rather than access to specific infrastructure.

## Glossary

- **CPaaS_Service**: The centralized Go service that stores, manages, and distributes contact plan information to DTN nodes
- **Contact**: A time-bounded, directed communication opportunity between two nodes with defined start time, end time, data rate, one-way light time, and link characteristics
- **Contact_Plan**: An ordered collection of Contacts valid for a specific time range, representing the complete connectivity schedule for a node or the network
- **Contact_Source**: A provider of contact information; classified as Manual, Orbital_Predictor, or Scheduled_Link
- **Manual_Source**: A Contact_Source where an operator creates contacts through the API
- **Orbital_Predictor**: A Contact_Source that computes contact windows from orbital mechanics (TLE data, ephemerides)
- **Scheduled_Link**: A Contact_Source representing pre-arranged communication agreements (e.g., ground station booking, relay allocation)
- **Node**: A DTN endpoint identified by a unique NodeID and Endpoint_ID, capable of sending, receiving, or relaying bundles
- **Node_Registry**: The component within CPaaS_Service that maintains the catalog of all known nodes and their capabilities
- **Subscription**: A registration by a DTN node or operator to receive contact plan updates, either via push notification or polling
- **Plan_Version**: A monotonically increasing integer identifying a specific revision of a contact plan
- **Conflict**: A condition where two or more Contacts on the same directed link overlap in time
- **Conflict_Resolution_Policy**: A configurable rule set that determines which Contact takes precedence when a Conflict is detected
- **Contact_Format**: The serialization format for a contact plan; supported formats include HDTN JSON, ION contact commands, and the CPaaS canonical JSON
- **DTN_Abstraction_Layer**: The existing RADIANT component providing a common interface to multiple DTN engines
- **Distribution_Channel**: The mechanism by which contact plans are delivered to nodes; either REST API (ground nodes) or OTA Bundle (space nodes)
- **Contact_Window**: The time interval during which a Contact is active (from start_time to end_time)
- **Link_Characteristics**: Properties of a communication link including data rate, one-way light time, bit error rate, and modulation type
- **Confidence_Level**: A value between 0.0 and 1.0 indicating the certainty that a predicted Contact will occur as scheduled

## Requirements

### Requirement 1: Contact Data Model

**User Story:** As a RADIANT developer, I want a canonical data model for contacts that captures all relevant link properties, so that contact information can be represented consistently regardless of its source or destination DTN engine.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL define a Contact struct containing: unique ContactID, source NodeID, destination NodeID, start_time (Unix epoch seconds), end_time (Unix epoch seconds), data_rate (bits per second), one-way light time (milliseconds), and Confidence_Level
2. THE CPaaS_Service SHALL define a Link_Characteristics struct containing: modulation type, frequency band, bit error rate, maximum transmission unit (bytes), and duplex mode (half or full)
3. THE CPaaS_Service SHALL associate each Contact with exactly one Link_Characteristics struct
4. THE CPaaS_Service SHALL define a Contact_Plan struct containing: PlanID, Plan_Version, valid_from time, valid_to time, generation timestamp, and an ordered list of Contacts sorted by start_time
5. WHEN a Contact is created, THE CPaaS_Service SHALL assign a unique ContactID using a UUID v4 format
6. THE CPaaS_Service SHALL enforce that end_time is strictly greater than start_time for every Contact
7. THE CPaaS_Service SHALL enforce that data_rate is a positive integer for every Contact

### Requirement 2: Node Registry

**User Story:** As a network operator, I want to register and manage DTN nodes in the contact service, so that contacts can reference valid endpoints and plans can be distributed to known nodes.

#### Acceptance Criteria

1. THE Node_Registry SHALL store node definitions containing: NodeID, Endpoint_ID, node type (Ground_Station, LEO_Satellite, GEO_Relay, Cislunar_Payload), display name, and capabilities
2. WHEN a node is registered, THE Node_Registry SHALL validate that the NodeID is unique across all registered nodes
3. WHEN a node is registered, THE Node_Registry SHALL validate that the Endpoint_ID conforms to either the "dtn" or "ipn" URI scheme
4. THE Node_Registry SHALL store node capabilities including: supported data rates, supported frequency bands, storage capacity (bytes), and DTN engine type
5. THE Node_Registry SHALL support updating node properties without changing the NodeID
6. IF a caller attempts to register a node with a duplicate NodeID, THEN THE Node_Registry SHALL return an error indicating the NodeID already exists
7. THE Node_Registry SHALL support listing all registered nodes with optional filtering by node type

### Requirement 3: Contact CRUD API

**User Story:** As a network operator, I want to create, read, update, and delete contacts through a REST API, so that I can manage the network's connectivity schedule programmatically.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL expose a REST endpoint `POST /api/v1/contacts` that creates a new Contact and returns the assigned ContactID
2. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/contacts/{contactID}` that returns the full Contact record
3. THE CPaaS_Service SHALL expose a REST endpoint `PUT /api/v1/contacts/{contactID}` that updates a Contact's mutable fields (start_time, end_time, data_rate, confidence, link characteristics)
4. THE CPaaS_Service SHALL expose a REST endpoint `DELETE /api/v1/contacts/{contactID}` that removes a Contact from the plan
5. WHEN a Contact is created or updated, THE CPaaS_Service SHALL validate that both source and destination NodeIDs reference registered nodes in the Node_Registry
6. WHEN a Contact is created or updated, THE CPaaS_Service SHALL increment the Plan_Version for all affected node plans
7. IF a Contact creation or update would violate the data model constraints, THEN THE CPaaS_Service SHALL return HTTP 400 with a descriptive error identifying the invalid field

### Requirement 4: Contact Query API

**User Story:** As a DTN engine or operator, I want to query contacts by node, time range, and link properties, so that I can retrieve relevant subsets of the contact plan efficiently.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/contacts` that supports query parameters: source_node, dest_node, from_time, to_time, min_data_rate, and min_confidence
2. WHEN the source_node parameter is provided, THE CPaaS_Service SHALL return only Contacts where the source NodeID matches
3. WHEN the from_time and to_time parameters are provided, THE CPaaS_Service SHALL return only Contacts whose time window overlaps with the specified range
4. THE CPaaS_Service SHALL support pagination via limit and offset query parameters with a default limit of 100
5. THE CPaaS_Service SHALL return query results sorted by start_time in ascending order
6. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/nodes/{nodeID}/plan` that returns the complete Contact_Plan for a specific node (all contacts where the node is source or destination)

### Requirement 5: Contact Source Management

**User Story:** As a network operator, I want to register different contact sources and track the provenance of each contact, so that I can understand where contact information originated and manage source-specific updates.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL define a Contact_Source struct containing: SourceID, source type (Manual, Orbital_Predictor, Scheduled_Link), display name, and configuration parameters
2. THE CPaaS_Service SHALL associate each Contact with exactly one Contact_Source via a SourceID field
3. THE CPaaS_Service SHALL expose a REST endpoint `POST /api/v1/sources` that registers a new Contact_Source
4. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/sources/{sourceID}/contacts` that returns all Contacts originating from a specific source
5. WHEN an Orbital_Predictor source is registered, THE CPaaS_Service SHALL store the prediction parameters (TLE data, prediction horizon, minimum elevation angle)
6. WHEN a Scheduled_Link source is registered, THE CPaaS_Service SHALL store the agreement metadata (parties, validity period, allocated capacity)
7. THE CPaaS_Service SHALL support bulk import of Contacts from a source via `POST /api/v1/sources/{sourceID}/contacts/bulk` accepting an array of Contact definitions

### Requirement 6: Orbital Prediction Integration

**User Story:** As a network operator, I want the service to generate contacts automatically from orbital prediction data, so that LEO satellite pass windows are computed without manual entry.

#### Acceptance Criteria

1. WHEN a TLE update is submitted for a LEO_Satellite node, THE CPaaS_Service SHALL recompute predicted contacts between that satellite and all registered Ground_Station nodes
2. THE CPaaS_Service SHALL expose a REST endpoint `POST /api/v1/predictions/generate` that accepts a satellite NodeID, ground station NodeID list, prediction horizon (hours), and minimum elevation angle (degrees)
3. WHEN predictions are generated, THE CPaaS_Service SHALL assign a Confidence_Level to each predicted Contact based on the TLE epoch age (confidence decreases as TLE ages)
4. WHEN new predictions are generated for a satellite, THE CPaaS_Service SHALL invalidate previous predicted Contacts from the same Orbital_Predictor source that fall within the new prediction horizon
5. THE CPaaS_Service SHALL store the TLE epoch timestamp and compute Confidence_Level as: 1.0 minus (0.05 multiplied by the number of days since epoch), with a minimum of 0.3
6. THE CPaaS_Service SHALL not generate predicted Contacts with a Confidence_Level below 0.3

### Requirement 7: Conflict Detection and Resolution

**User Story:** As a network operator, I want the service to detect and resolve conflicts when contacts overlap on the same link, so that DTN engines receive unambiguous contact plans.

#### Acceptance Criteria

1. WHEN a Contact is created or updated, THE CPaaS_Service SHALL check for time overlap with existing Contacts on the same directed link (same source and destination nodes)
2. WHEN a Conflict is detected, THE CPaaS_Service SHALL apply the configured Conflict_Resolution_Policy to determine which Contact takes precedence
3. THE CPaaS_Service SHALL support the following Conflict_Resolution_Policies: highest_confidence (predicted contacts yield to confirmed contacts), latest_version (most recently created contact wins), manual_priority (operator-assigned priority field), and source_priority (source type ranking: Scheduled_Link > Manual > Orbital_Predictor)
4. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/conflicts` that returns all currently detected unresolved conflicts
5. THE CPaaS_Service SHALL expose a REST endpoint `POST /api/v1/conflicts/{conflictID}/resolve` that allows an operator to manually resolve a conflict by selecting the winning Contact
6. WHEN a Conflict is resolved automatically, THE CPaaS_Service SHALL log the resolution decision including the policy applied, the winning ContactID, and the superseded ContactID
7. IF the configured policy is unable to resolve a Conflict deterministically, THEN THE CPaaS_Service SHALL mark the Conflict as unresolved and notify subscribed operators

### Requirement 8: Plan Distribution via REST

**User Story:** As a ground station operator, I want to retrieve my node's contact plan in the format required by my DTN engine, so that my node always operates with current routing information.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/nodes/{nodeID}/plan/export` that accepts a format query parameter specifying the desired Contact_Format (hdtn_json, ion_commands, cpaas_canonical)
2. WHEN the hdtn_json format is requested, THE CPaaS_Service SHALL serialize the plan using the HDTN contact plan JSON schema with fields: contact, source, dest, startTime, endTime, rateBitsPerSec, and owlt
3. WHEN the ion_commands format is requested, THE CPaaS_Service SHALL serialize the plan as ION contact and range commands
4. THE CPaaS_Service SHALL include the Plan_Version and generation timestamp in the export response headers
5. WHEN a node polls for its plan and the Plan_Version has not changed since the last retrieval (indicated by If-None-Match header), THE CPaaS_Service SHALL return HTTP 304 Not Modified
6. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/nodes/{nodeID}/plan/diff` that accepts a from_version parameter and returns only the contacts added, modified, or removed since that version

### Requirement 9: Plan Subscription and Push Notification

**User Story:** As a DTN node operator, I want to subscribe to plan updates and receive push notifications when my contact plan changes, so that my node reacts to schedule changes without continuous polling.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL expose a REST endpoint `POST /api/v1/subscriptions` that registers a Subscription with fields: subscriber NodeID, callback URL, and notification format (webhook or websocket)
2. WHEN a node's Contact_Plan is updated (contacts added, modified, or removed), THE CPaaS_Service SHALL send a notification to all active Subscriptions for that node within 5 seconds
3. THE CPaaS_Service SHALL include the new Plan_Version, a summary of changes (contacts added count, modified count, removed count), and a link to retrieve the full updated plan in each notification
4. IF a webhook notification delivery fails (non-2xx response or timeout after 10 seconds), THEN THE CPaaS_Service SHALL retry delivery up to 3 times with exponential backoff (10s, 30s, 90s)
5. THE CPaaS_Service SHALL expose a REST endpoint `DELETE /api/v1/subscriptions/{subscriptionID}` that removes a Subscription
6. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/subscriptions` that lists all active Subscriptions with optional filtering by NodeID

### Requirement 10: DTN Abstraction Layer Integration

**User Story:** As a RADIANT developer, I want CPaaS to integrate with the DTN Abstraction Layer's ContactPlanProvider interface, so that any registered DTN engine automatically receives contact plan updates from the centralized service.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL implement the DTN Abstraction Layer's `ContactPlanProvider` interface, providing `Load`, `List`, and `QueryActiveContacts` methods
2. WHEN the DTN Abstraction Layer calls `ApplyContactPlan` on an Engine adapter, THE CPaaS_Service SHALL provide the contacts translated into the engine-specific format
3. THE CPaaS_Service SHALL expose a `PlanUpdater` component that monitors Plan_Version changes and automatically invokes `ApplyContactPlan` on all locally registered Engine adapters
4. WHEN a new Plan_Version is available, THE PlanUpdater SHALL retrieve the diff from the previous version and apply only the changed contacts to the Engine adapter
5. IF an Engine adapter rejects a contact plan update, THEN THE PlanUpdater SHALL log the rejection reason and retry after 30 seconds
6. THE CPaaS_Service SHALL translate the canonical Contact model to the format required by each Engine adapter (HDTN JSON contacts, ION contact/range commands, ESA DTN schedule entries)

### Requirement 11: OTA Plan Distribution for Space Nodes

**User Story:** As a mission operator, I want the service to distribute contact plan updates to spacecraft as DTN bundles during contact windows, so that space nodes maintain current routing information despite intermittent connectivity.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL generate Plan Update Bundles for space nodes (LEO_Satellite, Cislunar_Payload) using the BPv7 administrative record format with destination `dtn://{nodeID}/cpaas/plan`
2. WHEN a space node's Contact_Plan is updated, THE CPaaS_Service SHALL queue a Plan Update Bundle targeting the ground station with the earliest upcoming contact window to that spacecraft
3. THE CPaaS_Service SHALL assign expedited priority to Plan Update Bundles to ensure transmission before routine data during limited contact windows
4. THE Plan Update Bundle payload SHALL contain the Contact_Plan serialized in cpaas_canonical format, including Plan_Version and valid_from/valid_to timestamps
5. THE Plan Update Bundle payload size SHALL not exceed 5000 bytes to ensure transmission within a single LEO pass at 9600 bps
6. IF the serialized plan exceeds 5000 bytes, THEN THE CPaaS_Service SHALL split the plan into multiple sequential bundles with sequence numbers and total count fields

### Requirement 12: Plan Versioning and Consistency

**User Story:** As a network operator, I want deterministic plan versioning so that all nodes converge to the same view of the contact schedule and stale updates are rejected.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL assign a monotonically increasing Plan_Version (positive integer starting at 1) to each contact plan revision
2. THE CPaaS_Service SHALL maintain a separate Plan_Version counter per node, incremented whenever that node's effective contact set changes
3. THE CPaaS_Service SHALL maintain a global Plan_Version counter incremented on any change to the contact store
4. WHEN a node receives a plan with Plan_Version V_new and currently holds Plan_Version V_current, THE node SHALL accept the plan if and only if V_new is greater than V_current
5. THE CPaaS_Service SHALL include a generation timestamp (Unix epoch seconds) and a SHA-256 hash of the plan contents in each versioned plan, enabling integrity verification
6. THE CPaaS_Service SHALL retain the last 10 plan versions per node to support diff queries and rollback

### Requirement 13: Contact Plan Format Serialization

**User Story:** As a RADIANT developer, I want to serialize and deserialize contact plans in multiple formats, so that the service can interoperate with different DTN engines and external systems.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL provide a `MarshalPlan` function that serializes a Contact_Plan to a byte slice in a specified Contact_Format
2. THE CPaaS_Service SHALL provide an `UnmarshalPlan` function that deserializes a byte slice in a specified Contact_Format into a Contact_Plan
3. FOR ALL valid Contact_Plan values, marshalling to cpaas_canonical format then unmarshalling SHALL produce an equivalent Contact_Plan (round-trip property)
4. THE CPaaS_Service SHALL support marshalling to HDTN JSON format producing a document with contacts array containing source, dest, startTime, endTime, rateBitsPerSec, and owlt fields
5. THE CPaaS_Service SHALL support marshalling to ION commands format producing text with "a contact" and "a range" command lines
6. IF `UnmarshalPlan` receives malformed input, THEN THE CPaaS_Service SHALL return a descriptive error identifying the parse failure location

### Requirement 14: Service Health and Metrics

**User Story:** As a RADIANT operator, I want to monitor the CPaaS service health and operational metrics, so that I can detect issues and understand service utilization.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/health` that returns service status (healthy, degraded, unhealthy), uptime, and database connectivity state
2. THE CPaaS_Service SHALL expose a REST endpoint `GET /api/v1/metrics` that returns: total contacts stored, total nodes registered, active subscriptions count, plan updates distributed in the last hour, and average plan generation latency
3. WHEN the database becomes unreachable, THE CPaaS_Service SHALL report degraded status and continue serving cached plan data for read requests
4. THE CPaaS_Service SHALL log all plan mutations (create, update, delete) with timestamp, actor, and affected ContactIDs for audit purposes

### Requirement 15: Access Control

**User Story:** As a network operator, I want role-based access control on the contact plan API, so that only authorized users can modify the network schedule while allowing read access for DTN nodes.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL support three roles: admin (full access), operator (create/update/delete contacts and sources), and node (read-only plan access and subscription management)
2. THE CPaaS_Service SHALL authenticate API requests using bearer tokens in the Authorization header
3. WHEN a request lacks a valid bearer token, THE CPaaS_Service SHALL return HTTP 401 Unauthorized
4. WHEN a request's token has insufficient role permissions for the requested operation, THE CPaaS_Service SHALL return HTTP 403 Forbidden with a message indicating the required role
5. THE CPaaS_Service SHALL support token generation via a `POST /api/v1/auth/token` endpoint accepting credentials and returning a time-limited bearer token

### Requirement 16: Persistence and Recovery

**User Story:** As a RADIANT operator, I want contact plan data persisted durably, so that the service recovers its full state after a restart without data loss.

#### Acceptance Criteria

1. THE CPaaS_Service SHALL persist all contacts, nodes, sources, subscriptions, and plan versions to a SQLite database
2. WHEN the CPaaS_Service starts, THE CPaaS_Service SHALL load the current state from the database and resume serving requests within 5 seconds for databases containing up to 100,000 contacts
3. THE CPaaS_Service SHALL use database transactions for all write operations to ensure atomicity
4. IF a write transaction fails, THEN THE CPaaS_Service SHALL return an error to the caller without partial state changes
5. THE CPaaS_Service SHALL support a configurable database file path via the service configuration file

