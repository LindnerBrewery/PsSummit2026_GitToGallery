# Everything On-Prem: From Git to Gallery with Open Source

**PowerShell + DevOps Global Summit 2026**
---

## About This Talk

Most organisations have policies — or simply preferences — that keep code and tooling on their own infrastructure. This session shows that you don't need cloud services to run a professional-grade PowerShell module pipeline. Everything demonstrated is free, open-source, and runs entirely on-premises inside a single Windows Server VM.

The talk walks through building a complete end-to-end pipeline:

- **Gitea** — self-hosted Git server with a web UI, organisations, teams, and template repositories
- **Gitea Actions** — CI/CD powered by `act_runner`, compatible with GitHub Actions workflow syntax
- **Nexus Repository Manager** — a private NuGet / PSGallery-compatible feed for publishing and consuming PowerShell modules
- **lldap** — a lightweight LDAP server that mocks Active Directory for authentication in both Gitea and Nexus
- **nginx** — reverse proxy with TLS termination so everything runs over HTTPS
- **Windows + WSL2** — running both Windows and Linux act runners side by side

The full walkthrough more than 40 steps and contains enough material for 4–6 hours of hands-on demo. The session focuses on the essential parts that illustrate the complete flow from a first `git push` to a published module in a private gallery.

---

## What's in This Repository

```
├── Vagrantfile                    # Automated VM provisioning (Hyper-V)
├── certs/                         # Pre-built TLS certificates for hostname "gittogallery"
├── scripts/                       # Numbered provisioning scripts (01–05) + helpers
├── configs/
│   ├── nginx/                     # nginx reverse proxy config
│   ├── gitea/                     # Custom .gitignore and README templates for Gitea
│   ├── custom/                    # Gitea landing page templates + branding
│   └── docker/
│       ├── lldap/                 # Lightweight LDAP (docker-compose)
│       ├── linux_act_runner/      # Linux Gitea Actions runner (Docker in WSL)
│       └── windows_act_runner/    # Windows Gitea Actions runner (Docker CE)
├── module/
│   └── Certificates/              # Example PowerShell module used throughout the demo
└── docs/
    ├── Setup-Readme.md            # Environment setup guide for attendees
    ├── Demo-Walkthrough.md        # Full walkthrough in readable Markdown (40 steps)
    └── Demo-Walkthrough.ps1       # Same walkthrough as a runnable PowerShell script
```

---

## Following Along

> **Start here:** [docs/Setup-Readme.md](docs/Setup-Readme.md)

The setup guide walks you through preparing a Windows Server 2025 VM with all required tools. You can use Vagrant + Hyper-V for an automated setup, or any other hypervisor (VMware, VirtualBox) with a manual setup.

**TL;DR:**
1. Clone this repo
2. Create (or provision) a **Windows Server 2025 VM** — name it `gittogallery` to use the pre-built certificates
3. Run the numbered scripts in `scripts/` in order (`01` → `05`)  
   — or just run `vagrant up` if you're on Hyper-V
4. Follow the steps in [docs/Demo-Walkthrough.md](docs/Demo-Walkthrough.md) or run them directly from [docs/Demo-Walkthrough.ps1](docs/Demo-Walkthrough.ps1) (Demo-Walkthrough will be published directly before the session)

The walkthrough is dense. The talk covers the most important steps, but the full 40+ step guide is there for anyone who wants to explore the complete pipeline at their own pace.

---

## Tech Stack

| Component | What it does | License |
|-----------|-------------|---------|
| [Gitea](https://gitea.com) | Self-hosted Git + web UI | MIT |
| [Gitea Actions / act_runner](https://gitea.com/gitea/act_runner) | CI/CD runner (GitHub Actions compatible) | MIT |
| [Nexus Repository OSS](https://www.sonatype.com/products/sonatype-nexus-oss) | Private NuGet / PSGallery feed | Apache 2.0 |
| [lldap](https://github.com/lldap/lldap) | Lightweight LDAP server (AD mock) | GPL-3.0 |
| [nginx](https://nginx.org) | Reverse proxy + TLS termination | BSD-2-Clause |
| [Docker CE](https://docs.docker.com/engine/install/) | Windows + Linux container runtime | Apache 2.0 |

---

## Talk Overview

| Phase | What's covered |
|-------|---------------|
| **1 — Git Server** | Install and configure Gitea, TLS via nginx, LDAP authentication repository templates |
| **2 — CI/CD** | Register Windows and Linux act runners, write Gitea Actions workflows, run the build pipeline |
| **3 — Private Gallery** | Set up Nexus, create a NuGet hosted repository, connect it to LDAP, publish a module, consume it as a PSRepository |
| **4 — End to End** | Push a change → Actions run Pester → module publishes to Nexus → team can `Install-Module` from private gallery |

---

## Questions / Contact

Feel free to contact me if you have questions about the setup or the demo content.
@emrys.macinally.de (bluesky)
@lindnerbrewery (X)
