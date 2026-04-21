# Redis sentinel helm chart

## Simple redis sentinel (no cluster or no-sentinel options) helm chart that uses official redis image
- architecture: replication only
- Redis Sentinel enabled by default
- one StatefulSet with 3 pods, each pod running:
  - one redis container
  - one redis-sentinel container
- one headless Service for stable pod DNS
- one Sentinel Service for client discovery
- one Secret for the Redis password
- one ConfigMap for base redis.conf and sentinel.conf (static config)
- one ConfigMap for containers startup scripts (dynamic config/replication/failover)
- per-pod Redis persistence with PVCs

init container should:
- copy statically defined config from the ConfigMap
  -> copy `redis.conf` to the Redis runtime path
  -> copy `sentinel.conf` to the Sentinel runtime path

static config in the ConfigMap should contain:
- for `redis.conf`:
  - bind / protected-mode / port / dir
  - value file redis config
- for `sentinel.conf`:
  - bind / protected-mode / port / dir
  - `sentinel resolve-hostnames yes`
  - `sentinel announce-hostnames yes`
  - value file sentinel config

container startup scripts (`common.sh`, `redis-start.sh`, `sentinel-start.sh`) should:
- evaluate if auth is set
- log actions
- start `redis-server` and `redis-server --sentinel` using the config already copied by the init container, plus dynamic runtime append
- add `replica-announce-ip` and `replica-announce-port` to the Redis config with FQDN/port instead of IPs
- ask sentinels who the master is:
  - no master -> probe redis instances for role:master -> fallback to redis-node-0

`redis-start.sh` should:
- determine the current master
- if local pod is not the master, append `replicaof`
- if auth is enabled, append `requirepass` and `masterauth`
- append `replica-announce-ip` and `replica-announce-port`
- log current master and whether this instance starts as master or replica
- start `redis-server`

`sentinel-start.sh` should:
- determine the current master
- append only runtime-specific Sentinel directives:
  - `sentinel monitor` (who sentinel should follow <master-name>, the <master> ip and <port>, and the <quorum> needed for starting a failover)
  - `sentinel announce-ip` (announce the <my_fqdn> of the sentinel instance to discovery process)
  - `sentinel announce-port` (announce the <sentinel_port> of the sentinel instance to discovery process)
  - `sentinel auth-pass` if auth is enabled
- log which master was selected
- start `redis-server --sentinel`

prestop scripts (`redis-prestop.sh`, `sentinel-prestop.sh`) should:
- graceful shutdown redis instances (redis-prestop):
  - if master instance, ask sentinel to failover to a new master
  - log whether failover was triggered and whether a new master was observed
- graceful shutdown sentinel instances (sentinel-prestop):
  - the local redis instance may also be stopping -> poll until local redis is no longer master (this avoids the local sentinel disappearing too early and delaying quorum for a new master election)
  - log what it is waiting for and when it is safe to stop

## TODO
- set default resources values
