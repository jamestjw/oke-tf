# Infrastructure Architecture Diagrams

## Runtime Infrastructure

```mermaid
flowchart TB
    users["Users / Developers"]
    cloudflare["Cloudflare DNS"]

    subgraph oci["OCI"]
        subgraph vcn["VCN"]
            igw[("Internet Gateway")]
            nat[("NAT Gateway")]
            sgw[("Service Gateway")]

            subgraph public["Public subnet"]
                lbsubnet["Load balancer subnet"]
            end

            subgraph private["Private subnets"]
                epsubnet["OKE endpoint subnet"]
                workersubnet["Worker subnet"]
                podsubnet["Pod subnet"]
            end

            pubrt[("Public route table")]
            prvrt[("Private route table")]
        end

        bastion["OCI Bastion"]

        subgraph okecluster["OKE cluster"]
            controlplane["Managed control plane\n(private endpoint)"]
            nodepool["Node pool"]

            subgraph workloads["Kubernetes workloads"]
                ingress["ingress-nginx\nLoadBalancer Service"]
                certmanager["cert-manager"]
                argocd["ArgoCD"]
                ingressns["ingress-nginx namespace"]
                certns["cert-manager namespace"]
                argons["argocd namespace"]
            end
        end
    end

    users -->|DNS lookup| cloudflare
    cloudflare -->|A/CNAME record| lbsubnet

    lbsubnet --> pubrt --> igw
    epsubnet --> prvrt --> nat
    workersubnet --> prvrt --> nat
    podsubnet --> prvrt --> nat
    prvrt --> sgw

    users -->|SSH allow list| bastion
    bastion -->|private access| workersubnet

    epsubnet -->|6443 / 12250| controlplane
    workersubnet --> nodepool
    podsubnet --> nodepool
    nodepool --> controlplane

    lbsubnet -->|external service| ingress
    ingress --> certmanager
    ingress --> argocd

    ingress --- ingressns
    certmanager --- certns
    argocd --- argons
```

## Notes

- The runtime diagram shows how OCI networking, OKE, Bastion, Kubernetes add-ons, and Cloudflare are actually connected.
- Use this diagram when explaining traffic flow or deployment behavior.
