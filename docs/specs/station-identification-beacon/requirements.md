# Requirements Document

## Introduction

Station Identification Beacon implements periodic transmission of BPv7 bundles containing the operator's callsign and station metadata in plaintext. This ensures compliance with amateur radio regulations (which require station identification at least every 10 minutes) and allows any third party demodulating the signal to identify the transmitting station — even when the wire format only carries numeric ipn:// EIDs that are opaque to observers.

The beacon is analogous to how FT8/WSPR protocols embed callsigns in message payloads. It operates independently of data traffic, transmitting identification bundles at configurable intervals via the existing HDTN infrastructure.

## Glossary

- **Beacon_Generator**: The Go package (`pkg/beacon/`) responsible for constructing beacon payload content and managing the periodic transmission timer.
- **Beacon_Bundle**: A standard BPv7 bundle carrying a plaintext identification payload, sent to a well-known beacon service number.
- **Beacon_Payload**: The human-readable plaintext content of a beacon bundle containing station identification fields.
- **Orchestrator**: The `cmd/dtn-node` Go process that manages HDTN lifecycle, telemetry, and now beacon injection.
- **HDTN**: NASA Glenn's High-rate Delay Tolerant Networking implementation used as the bundle protocol engine.
- **Beacon_Service_Number**: A well-known service number (2048) used as the destination demux for beacon bundles, enabling receivers to identify beacon traffic.
- **Beacon_Interval**: The time period between consecutive beacon transmissions, defaulting to 10 minutes.
- **Grid_Square**: A Maidenhead locator string representing the station's geographic position (e.g., "IO91vl").

## Requirements

### Requirement 1: Periodic Beacon Transmission

**User Story:** As a licensed amateur radio operator, I want my DTN node to automatically transmit station identification at regular intervals, so that I comply with regulatory requirements and any receiver can identify my station.

#### Acceptance Criteria

1. WHEN the Orchestrator starts and beacon configuration is enabled, THE Beacon_Generator SHALL begin transmitting Beacon_Bundles at the configured Beacon_Interval.
2. WHILE the HDTN process is running, THE Beacon_Generator SHALL continue transmitting Beacon_Bundles regardless of whether there is active data traffic.
3. WHEN the Beacon_Interval elapses, THE Beacon_Generator SHALL inject a new Beacon_Bundle into HDTN within 5 seconds of the interval expiry.
4. WHEN the Orchestrator receives a shutdown signal, THE Beacon_Generator SHALL stop the beacon timer and cease transmission.

### Requirement 2: Beacon Payload Format

**User Story:** As a third party demodulating the signal, I want beacon payloads to be human-readable plaintext, so that I can identify the transmitting station without specialized decoding tools.

#### Acceptance Criteria

1. THE Beacon_Payload SHALL be encoded as UTF-8 plaintext (not binary or CBOR).
2. THE Beacon_Payload SHALL contain the station callsign as the first field.
3. THE Beacon_Payload SHALL contain the node name, the dtn:// EID, and a UTC timestamp in ISO 8601 format.
4. WHERE the station has a configured grid square, THE Beacon_Payload SHALL include the Maidenhead Grid_Square locator.
5. THE Beacon_Payload SHALL use a line-oriented key-value format parseable by both humans and simple text parsers.
6. FOR ALL valid beacon configurations, formatting a Beacon_Payload then parsing the formatted text SHALL produce an equivalent payload structure (round-trip property).

### Requirement 3: Beacon Bundle Addressing

**User Story:** As a network operator, I want beacon bundles sent to a well-known service number, so that receivers can filter and identify beacon traffic from regular data bundles.

#### Acceptance Criteria

1. THE Beacon_Generator SHALL set the destination EID of each Beacon_Bundle to use Beacon_Service_Number 2048.
2. THE Beacon_Generator SHALL set the source EID of each Beacon_Bundle to the node's configured dtn:// EID with a "/beacon" service demux.
3. WHEN the node uses ipn:// addressing for routing, THE Beacon_Generator SHALL set the destination to `ipn:<nodeNumber>.2048` for local broadcast.
4. THE Beacon_Bundle SHALL have a lifetime equal to the configured Beacon_Interval, so that stale beacons expire before the next transmission.

### Requirement 4: Beacon Interval Configuration

**User Story:** As a node operator, I want to configure the beacon interval, so that I can adjust identification frequency for different regulatory environments or link conditions.

#### Acceptance Criteria

1. THE Orchestrator SHALL read beacon interval configuration from the node YAML/JSON configuration file under a `beacon` section.
2. THE Beacon_Generator SHALL use a default interval of 600 seconds (10 minutes) when no interval is explicitly configured.
3. IF the configured beacon interval is less than 60 seconds, THEN THE Orchestrator SHALL reject the configuration and report an error at startup.
4. IF the configured beacon interval is greater than 3600 seconds, THEN THE Orchestrator SHALL log a warning that the interval may not satisfy regulatory requirements.
5. WHEN the beacon section is absent or `enabled` is set to false in configuration, THE Orchestrator SHALL not start the Beacon_Generator.

### Requirement 5: Beacon Configuration Schema

**User Story:** As a node operator, I want to configure beacon parameters in the existing node configuration file, so that I do not need separate configuration for the beacon subsystem.

#### Acceptance Criteria

1. THE Orchestrator SHALL accept beacon configuration fields including: `enabled` (boolean), `interval_seconds` (integer), `callsign` (string), `grid_square` (string, optional), and `destination_eid` (string, optional).
2. IF the `callsign` field is empty or missing when beacon is enabled, THEN THE Orchestrator SHALL fall back to the top-level `callsign` field from the node configuration.
3. IF no callsign is available from either the beacon section or the top-level configuration, THEN THE Orchestrator SHALL reject the configuration and report an error.
4. WHERE a `destination_eid` is provided in beacon configuration, THE Beacon_Generator SHALL use that EID instead of the default Beacon_Service_Number destination.

### Requirement 6: Bundle Injection via HDTN

**User Story:** As a developer, I want the beacon to use the existing HDTN bundle injection mechanism, so that beacon bundles are routed and transmitted like any other bundle.

#### Acceptance Criteria

1. THE Beacon_Generator SHALL inject Beacon_Bundles into HDTN using the `bpsendfile` command-line tool or HDTN's REST API.
2. IF bundle injection fails, THEN THE Beacon_Generator SHALL log the error and retry on the next interval without crashing.
3. THE Beacon_Generator SHALL write the beacon payload to a temporary file before invoking `bpsendfile`, and remove the temporary file after injection completes.
4. WHEN HDTN is not in the Running state, THE Beacon_Generator SHALL skip beacon injection and log a warning.

### Requirement 7: Beacon Payload Parser

**User Story:** As a receiving station operator, I want to parse received beacon payloads, so that I can display station identification information from neighbouring nodes.

#### Acceptance Criteria

1. THE Beacon_Generator package SHALL export a Parse function that accepts a Beacon_Payload byte slice and returns a structured beacon record or an error.
2. WHEN a Beacon_Payload contains all required fields (callsign, node name, dtn:// EID, timestamp), THE Parse function SHALL return a valid beacon record.
3. IF a Beacon_Payload is missing required fields, THEN THE Parse function SHALL return a descriptive error indicating which field is missing.
4. THE Pretty_Printer SHALL format beacon records back into valid Beacon_Payload text.
5. FOR ALL valid beacon records, parsing then printing then parsing SHALL produce an equivalent beacon record (round-trip property).

### Requirement 8: Beacon Observability

**User Story:** As a node operator, I want visibility into beacon operation, so that I can verify my station is identifying correctly.

#### Acceptance Criteria

1. WHEN a Beacon_Bundle is successfully injected, THE Beacon_Generator SHALL log the transmission at INFO level including the callsign and timestamp.
2. THE Orchestrator SHALL expose beacon status (last transmission time, total beacons sent, next scheduled transmission) via the existing telemetry HTTP endpoint.
3. WHEN the Orchestrator starts with beacon enabled, THE Orchestrator SHALL log the beacon configuration including callsign, interval, and destination EID.
