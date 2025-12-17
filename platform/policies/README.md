# Policy Governance — Operator Overview

Audience: Platform operators and release engineers. For technical design and initiative details see `platform/policies/docs/README.md`.

This folder contains the operational surface for policy initiatives, assignments and automation that implement the Azure Security Benchmark (ASB) within the CAF landing zone.

Key responsibilities:
- Deploy and manage initiative definitions and archetype assignments
- Run compliance validation and generate reports
- Phase enforcement from audit → enforce using parameter-driven deployments

Core pointers
- Canonical technical reference: `platform/policies/docs/README.md`
- Policy reference and operator guidance: `platform/policies/docs/POLICY-REFERENCE-GUIDE.md`
- Mapping of ASB controls to initiatives: `platform/policies/config/asb-mapping/`

Quickstart (operator steps)

Prerequisites:
- `az` (Azure CLI) authenticated
- Owner / Policy Contributor at tenant root
- Management groups deployed (`platform/management/mg-rai.bicep`)

Deploy the policies pipeline (typical):
```powershell
cd platform/policies/scripts
./deploy-policies.ps1
```

Validate compliance and produce reports:
```powershell
./validate-policy-compliance.ps1
```

Run the full pipeline (deploy + validate):
```powershell
./invoke-policy-pipeline.ps1
```

Folder layout (high level)
```
platform/policies/
├─ bicep/           # initiative definitions, assignment modules
├─ config/          # parameters and ASB control mappings
├─ scripts/         # operator automation (deploy/validate/invoke)
├─ generated/       # reports and logs (output)
└─ docs/            # canonical technical docs and guides
```

Recommended operator practices
- Keep parameter files (enforcementMode etc.) under `config/parameters/` and review before deploying.
- Use the phased enforcement approach: audit → selective enforce → broader enforce.
- Inspect `generated/` reports locally before changing enforcement modes.

Where to find more detail
- Full design, initiative composition and archetype patterns: `platform/policies/docs/README.md`
- Policy reference with examples and fixes: `platform/policies/docs/POLICY-REFERENCE-GUIDE.md`
- Troubleshooting, advanced usage and report format: `platform/policies/docs/DEPLOYMENT-GUIDE.md` and `platform/policies/docs/COMPLIANCE-GUIDE.md`


