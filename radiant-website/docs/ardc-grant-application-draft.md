# ARDC Grant Application Draft — RADIANT

**Category:** Space-Based Communications / Research & Development  
**Applicant Organisation:** AMSAT-UK (not-for-profit membership organisation, UK)  
**Application deadline:** 6 July 2026  
**Apply at:** https://grants.ardc.net

---

## Project Title

**RADIANT: Radio Amateur DTN Infrastructure for Accessible Networked Telecommunications**

**Project website:** https://radiant.amsat-uk.org

## Why (Impact Statement)

There is currently no open-source, amateur-radio-compliant ground station software that enables radio amateurs to participate in Delay/Disruption-Tolerant Networking (DTN) for cislunar and deep-space communications. Existing DTN implementations require specialist knowledge to configure and operate. Commercial ground station software is proprietary and expensive.

RADIANT bridges this gap by providing open-source, backend-agnostic tooling that lets any licensed amateur operator run a DTN ground station node, accept bundles from terrestrial peers over standard TCP, store them during link outages, and forward them to spacecraft over LTP/UDP when contact windows open. The architecture abstracts the underlying DTN engine — currently supporting ION-DTN with the design allowing additional backends — so operators are not locked into a single implementation.

This directly supports the amateur radio community's ability to participate in the emerging cislunar communications infrastructure alongside agencies and commercial operators.

## What (Concrete Deliverables)

With ARDC funding, we will deliver:

1. **Production-ready ground station software** — The `radiant-ion` daemon with HTTP/JSON management API, deployed on AMSAT-UK infrastructure. Provides backend-agnostic lifecycle management, bundle statistics, and hot reconfiguration of contacts and neighbors through a DTN abstraction layer.

2. **TCPCLv3 terrestrial gateway** — Allows any amateur DTN node on the internet to connect via standard Bundle Protocol over TCP (port 4556) and deliver bundles into the ground station network, regardless of which DTN engine the ground station runs.

3. **LTP Convergence Layer Adapter** — A Rust-based LTP implementation enabling interoperability between different DTN implementations over amateur radio links. Demonstrates that the architecture is not tied to a single vendor's stack.

4. **Three demonstration scenarios** showing store-and-forward behaviour:
   - Delayed uplink (bundles stored during link outage, burst-transmitted when contact opens)
   - Immediate uplink (real-time forwarding)
   - Delayed downlink (receiving bundles from a satellite after acquisition of signal)

5. **Documentation and operator guide** — Enabling other amateur groups to replicate the ground station setup using commodity hardware and free software.

6. **Open source release** — All code MIT-licensed on GitHub, with configuration generators, deployment automation, and example configurations for the G4DPZ ground station.

## Who (Team & Qualifications)

- **David Johnson, G4DPZ** — Project lead. Software engineer with 20+ years experience. AMSAT-UK member. Built the existing RADIANT prototype demonstrating multi-implementation DTN interoperability over LTP. Holds amateur radio licence (G4DPZ).

- **AMSAT-UK** — Applicant organisation. UK not-for-profit membership organisation supporting amateur radio satellite communications. Operates ground station infrastructure and has a track record of supporting experimental space communications projects (including FUNcube / AMSAT-OSCAR-73).

### Contributing Partners

- **AMSAT-DL** — German amateur satellite organisation. Contributing ground station infrastructure and operational expertise for European DTN node deployment and testing.

- **Goonhilly Earth Station** — Commercial deep-space antenna facility in Cornwall, UK. Contributing technical advisory support and potential access to antenna time for cislunar link testing.

These partnerships demonstrate cross-sector support from the amateur radio community and commercial ground station operators — validating RADIANT's relevance to both constituencies.

[Add additional team members here if applicable]

## Timeline

| Phase | Duration | Deliverables |
|-------|----------|-------------|
| 1. Infrastructure | Months 1-2 | Production VM deployment, DTN engine running, TCPCLv3 gateway operational |
| 2. Integration | Months 3-4 | LTP interop testing with multiple DTN implementations, documentation |
| 3. Demonstration | Months 5-6 | Three scenarios demonstrated end-to-end, operator guide published, community testing |
| 4. Community | Months 7-8 | Outreach to AMSAT network, second ground station node online, conference presentation |

## Budget

| Item | Cost (USD) | Notes |
|------|-----------|-------|
| Cloud VM infrastructure (12 months) | $1,200 | Ubuntu VM with static IP for DTN ground station |
| Hardware: ground station SDR + antenna for live testing | $2,000 | RTL-SDR or similar + UHF/VHF antenna system |
| Conference travel (1 presentation) | $1,500 | AMSAT-UK Colloquium or similar |
| Documentation & community materials | $500 | Hosting, diagrams, video production |
| Indirect costs (15%) | $780 | Organisation overhead |
| **Total** | **$5,980** | |

**Note on personnel costs:** All development time is contributed on a voluntary basis by David Johnson (G4DPZ). No developer payments are included in this budget — the grant covers infrastructure and materials only.

**Other funding / in-kind contributions:**
- AMSAT-UK: existing ground station infrastructure, volunteer testing time, organisational support
- AMSAT-DL: European ground station node hosting, operator time for interop testing
- Goonhilly Earth Station: technical advisory, potential antenna time for cislunar link validation

## Open Access / Open Source

All software is MIT-licensed and hosted on GitHub:
- https://github.com/g4dpz/cislunar_proposal

All protocols used over amateur radio links are publicly documented (BPv7, LTP, TCPCL, IPN routing). No encryption is used on any over-the-air link, complying with ITU Article 25 and applicable national regulations.

## Current Status (What Already Works)

- Backend-agnostic DTN abstraction layer — designed and implemented
- DTN engine lifecycle management via HTTP API — deployed and operational
- Multi-implementation LTP interop test (1MB bundle transfer) — passing reliably
- TCPCLv3 inbound convergence layer — configured and tested
- Contact graph routing with scheduled contact windows — demonstrated
- Direct ION controller script — working on macOS and Ubuntu
- Three timing scenarios (delayed/immediate uplink, delayed downlink) — all starting cleanly

## Alignment with ARDC Priority Areas

**Space-Based Communications:**
- Creates open-source infrastructure for amateur satellite DTN
- Engages amateur radio community in cislunar wireless experimentation
- Enables participation alongside agency missions (NASA, ESA)

**Research & Development:**
- Open hardware/software components supporting learning and experimentation
- Low-cost, flexible design (runs on a $10/month VM)
- Backend-agnostic architecture — not locked to a single DTN implementation
- Novel amateur radio application of delay-tolerant networking

---

## Notes for Submission

- Submit at https://grants.ardc.net
- Answer the questions on the form using the narrative above
- Attach budget as spreadsheet
- Can email giving@ardc.net to discuss before submitting
- AMSAT-UK is the applicant org (not-for-profit membership organisation, international equivalent of 501(c)(3))
