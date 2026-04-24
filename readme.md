# Redis Sentinel Helm Chart

This chart deploys a Redis setup with Redis Sentinel, using the official `redis` image. It creates a single StatefulSet where every pod runs one Redis container and one Sentinel container, plus an optional metrics exporter sidecar.

The chart aim to offer:
- replication only
- Sentinel always enabled
- one StatefulSet
- fixed Sentinel master set name: `mymaster`
- optional password auth via a pre-created Secret
- optional metrics via `redis_exporter` and `ServiceMonitor`

## Basic deployment
This Helm chart already covers the most basic deployment, you will mostly need to set `resources.redis` based on your use-case.  
If you scale `replicaCount` above `3`, you should also review `sentinel.quorum`.  
By default, the chart stores data in a `1Gi` PVC, but you can disable persistence or resize it. Password authentication is disabled by default. If you enable it with `auth.enabled`, you must provide `auth.existingSecret`. `auth.existingSecretPasswordKey` only needs to be changed when the Secret key is not `redis-password`.

## Values reference

### Topology

| Value | Description | Default | Required |
|---|---|---|---|
| `replicaCount` | Number of Redis + Sentinel pods. Must be at least 3 for Sentinel quorum. An odd value is recommended. | `3` | No |

### Image

| Value | Description | Default |
|---|---|---|
| `image.repository` | Redis image repository. | `redis` |
| `image.tag` | Redis image tag. | `8.6.2` |
| `image.pullPolicy` | Image pull policy for Redis and Sentinel containers. | `IfNotPresent` |

### Auth

| Value | Description | Default | Required |
|---|---|---|---|
| `auth.enabled` | Enable Redis and Sentinel password authentication. | `false` | No |
| `auth.existingSecret` | Name of a pre-created Secret containing the Redis password. | `""` | When enabled |
| `auth.existingSecretPasswordKey` | Secret key containing the password. Only change it when the Secret key is not `redis-password`. | `redis-password` | No |

### Redis

| Value | Description | Default |
|---|---|---|
| `service.port` | Redis TCP port. | `6379` |
| `redisConfig` | Raw `redis.conf` directives appended to the built-in base config. | `appendonly yes`, `save ""` |

### Sentinel

| Value | Description | Default |
|---|---|---|
| `sentinel.port` | Sentinel TCP port. | `26379` |
| `sentinel.quorum` | Number of Sentinels required to agree before declaring the master down. Must be < `replicaCount`. | `2` |
| `sentinel.downAfterMilliseconds` | Time before a master is considered down by Sentinel. | `60000` |
| `sentinel.failoverTimeout` | Failover timeout used by Sentinel. | `180000` |
| `sentinel.parallelSyncs` | Number of replicas reconfigured in parallel after failover. | `1` |

The Sentinel master set name is hardcoded to `mymaster`.

### Persistence

| Value | Description | Default |
|---|---|---|
| `persistence.enabled` | Enable PVC-backed Redis data storage. When disabled, `emptyDir` is used. | `true` |
| `persistence.storageClass` | StorageClass name for Redis PVCs. | `"nodelocal-nvme"` |
| `persistence.accessModes` | Access modes for the Redis PVCs. | `["ReadWriteOnce"]` |
| `persistence.size` | Size of each Redis PVC. | `1Gi` |

### Availability

| Value | Description | Default |
|---|---|---|
| `pdb.minAvailable` | Minimum number of pods that must remain available during voluntary disruptions. Must be lower than `replicaCount`. | `2` |
| `terminationGracePeriodSeconds` | Pod termination grace period. Must be long enough for Sentinel-driven failover during shutdown (>20s is recommended). | `30` |

### Monitoring

| Value | Description | Default |
|---|---|---|
| `metrics.enabled` | Enable the `redis_exporter` sidecar, metrics Service, and `ServiceMonitor`. | `true` |
| `metrics.image.repository` | Metrics exporter image repository. | `oliver006/redis_exporter` |
| `metrics.image.tag` | Metrics exporter image tag. | `v1.82.0` |
| `metrics.image.pullPolicy` | Metrics exporter pull policy. | `IfNotPresent` |
| `metrics.port` | Metrics exporter port. | `9121` |
| `metrics.serviceMonitor.interval` | Scrape interval for the generated `ServiceMonitor`. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Optional scrape timeout for the generated `ServiceMonitor`. | `""` |
| `metrics.serviceMonitor.labels` | Extra labels added to the generated `ServiceMonitor`. | `{}` |
| `metrics.extraEnvVars` | Extra environment variables passed to the metrics exporter sidecar. | `[]` |

### Resources

TODO
| Value | Description | Default |
|---|---|---|
| `resources.redis` | Resource requests/limits for the Redis container. | `{}` |
| `resources.sentinel` | Resource requests/limits for the Sentinel container. | `{}` |
| `resources.metrics` | Resource requests/limits for the metrics exporter sidecar. | `{}` |
| `resources.init` | Resource requests/limits for the init container. | `{}` |

### Scheduling

| Value | Description | Default |
|---|---|---|
| `affinity` | Additional affinity rules applied to the pods. | `{}` |
| `nodeSelector` | Node selector for the pods. | `{}` |
| `tolerations` | Pod tolerations. | `[]` |
| `topologySpreadConstraints` | Extra topology spread constraints appended to the built-in zone spread rule. | `[]` |

### Probes

| Value | Description | Default |
|---|---|---|
| `probes.liveness.initialDelaySeconds` | Liveness probe initial delay for Redis and Sentinel. | `20` |
| `probes.liveness.periodSeconds` | Liveness probe period. | `10` |
| `probes.liveness.timeoutSeconds` | Liveness probe timeout. | `5` |
| `probes.liveness.failureThreshold` | Liveness probe failure threshold. | `5` |
| `probes.readiness.initialDelaySeconds` | Readiness probe initial delay for Redis and Sentinel. | `5` |
| `probes.readiness.periodSeconds` | Readiness probe period. | `5` |
| `probes.readiness.timeoutSeconds` | Readiness probe timeout. | `3` |
| `probes.readiness.failureThreshold` | Readiness probe failure threshold. | `5` |

### Pod customization and security

| Value | Description | Default |
|---|---|---|
| `podAnnotations` | Extra pod annotations. | `{}` |
| `podLabels` | Extra pod labels. | `{}` |
| `commonLabels` | Extra labels applied to chart-managed resources. | `{}` |
| `securityContext` | Pod security context. | `fsGroup: 1001`, `runAsUser: 1001`, `runAsGroup: 1001`, `runAsNonRoot: true` |
| `containerSecurityContext` | Container security context used by Redis, Sentinel, metrics, and init containers. | `allowPrivilegeEscalation: false`, `drop: [ALL]`, `readOnlyRootFilesystem: true` |

## How it works

### Topology

The chart creates one StatefulSet with `replicaCount` pods. Each pod contains:
- one Redis server
- one Redis Sentinel process
- one optional `redis_exporter` sidecar

### Derived names

- StatefulSet name: `<releaseName>-node`
- Pod names: `<releaseName>-node-0`, `<releaseName>-node-1`, ...
- Headless service name: `<releaseName>-headless`
- Main service name: `<releaseName>`
- Metrics service name: `<releaseName>-metrics`
- Config ConfigMap name: `<releaseName>-config`
- Scripts ConfigMap name: `<releaseName>-scripts`
- PDB name: `<releaseName>`

The `-node` suffix is preserved on pod names for compatibility with old Bitnami Helm chart.

### Services

The chart creates:
- a headless Service
- a ClusterIP Service exposing both Redis and Sentinel ports
- an optional metrics Service

The headless service is the important one for stable per-pod addressing such as:
- `<releaseName>-node-0.<releaseName>-headless.<namespace>.svc.cluster.local`

The main ClusterIP Service selects all pods in the StatefulSet. It is not a "current master" Service; Redis traffic to that service may hit either the master or a replica.

### Bootstrap and failover

Static `redis.conf` and `sentinel.conf` are stored in a ConfigMap and copied by the init container to writable runtime paths.

At startup:
- `redis-start.sh` determines the current master and appends `replicaof` only when needed
- `sentinel-start.sh` determines the current master and appends runtime-specific Sentinel parameters

Master discovery order is:
1. ask reachable Sentinels for the current master of `mymaster`
2. probe Redis instances for one already reporting `role:master`
3. fall back to pod `0` (on fresh release deployment)

During shutdown:
- Redis `preStop` triggers `SENTINEL FAILOVER mymaster` when the local Redis is the master
- Sentinel `preStop` waits until the local Redis is no longer master before exiting

### Monitoring

When `metrics.enabled=true`, the chart creates:
- a `redis_exporter` sidecar in every pod
- a ClusterIP Service exposing the exporter
- a `ServiceMonitor` for Prometheus Operator

## Metrics

With `metrics.enabled=true`, Prometheus Operator can scrape the generated `ServiceMonitor` directly.

If you need extra exporter environment variables, for example to align with your Redis auth model, use:

```yaml
metrics:
  extraEnvVars:
    - name: REDIS_USER
      value: default
```
