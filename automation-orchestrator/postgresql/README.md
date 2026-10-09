# PostgreSQL for Automation Orchestrator

Deploy PostgreSQL with the three databases required by Automation Orchestrator.

## Overview

Automation Orchestrator requires three PostgreSQL databases:
- **orchestrator** - Main backend database for the Automation Orchestrator
- **temporal** - Temporal workflow engine database
- **temporal_visibility** - Temporal visibility store (name is fixed, cannot be changed)

This deployment uses Red Hat's `rhel9/postgresql-15` image and includes:
- PostgreSQL 15 StatefulSet with persistent storage
- Automatic database initialization Job
- Required extensions (pgcrypto for the orchestrator database)
- Two database users with appropriate privileges

## Database Configuration

### Users
- **orchestrator** - Owner of the `orchestrator` database
- **temporal** - Owner of `temporal` and `temporal_visibility` databases

### Privileges
Each user has ALL PRIVILEGES on their respective databases, required for schema migrations that perform DDL operations (CREATE, ALTER, DROP tables/indexes).

### Extensions
- **pgcrypto** - Installed on the orchestrator database for encryption functions

## Overlays

### `default`
Standard PostgreSQL deployment with:
- 1 replica (single instance)
- 10Gi PersistentVolume using default storage class
- Default PostgreSQL 15 image from Red Hat

**Usage:**
```bash
oc apply -k automation-orchestrator/postgresql/overlays/default
```

### `custom-storage`
Customized storage configuration for production environments.

**Features:**
- Configurable storage class (edit `pvc-patch.yaml`)
- Customizable storage size (default 50Gi in patch)
- Example for different storage tiers

**Usage:**
```bash
# Edit the storage class and size first
vim automation-orchestrator/postgresql/overlays/custom-storage/pvc-patch.yaml

# Apply with custom storage
oc apply -k automation-orchestrator/postgresql/overlays/custom-storage
```

**Example storage classes:**
- `gp3` - AWS General Purpose SSD
- `fast-ssd` - High-performance SSD
- `standard` - Standard persistent disk
- Your cluster's custom storage classes

## Deployment

### Prerequisites
- OpenShift 4.12+ or Kubernetes 1.25+
- Storage class available in the cluster
- Sufficient resources for PostgreSQL

### Installation Steps

1. **Deploy PostgreSQL:**
   ```bash
   oc apply -k automation-orchestrator/postgresql/overlays/default
   ```

2. **Wait for StatefulSet to be ready:**
   ```bash
   oc wait --for=condition=ready pod -l app=postgresql -n automation-orchestrator --timeout=5m
   ```

3. **Verify database initialization:**
   ```bash
   # Check if the initialization Job completed
   oc get job postgresql-init-databases -n automation-orchestrator

   # View initialization logs
   oc logs job/postgresql-init-databases -n automation-orchestrator
   ```

4. **Verify databases were created:**
   ```bash
   # Connect to PostgreSQL pod
   oc exec -it postgresql-0 -n automation-orchestrator -- psql -U postgres

   # List databases
   \l

   # Should show: postgres, orchestrator, temporal, temporal_visibility
   ```

## Configuration

### Changing PostgreSQL Passwords

The default passwords are set in `base/configmap-env.yaml`:

```yaml
POSTGRESQL_PASSWORD: "changeme"
```

For production:
1. Create a Secret with your password
2. Patch the StatefulSet to use the Secret instead of ConfigMap
3. Update `configmap-init.yaml` with matching passwords for the database users

### Resource Limits

Edit the StatefulSet to add resource limits:

```yaml
# Create a patch in your overlay
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  template:
    spec:
      containers:
      - name: postgresql
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
```

### Tuning PostgreSQL

Adjust PostgreSQL settings in `base/configmap-env.yaml`:

```yaml
POSTGRESQL_MAX_CONNECTIONS: "200"
POSTGRESQL_SHARED_BUFFERS: "256MB"
POSTGRESQL_EFFECTIVE_CACHE_SIZE: "1GB"
POSTGRESQL_WORK_MEM: "8MB"
```

## Storage Considerations

### Sizing

Recommended storage sizes:
- **Development**: 10Gi (default)
- **Staging**: 50Gi
- **Production**: 100Gi+ (depends on workload)

### Performance

For production workloads:
- Use SSD-backed storage classes (gp3, fast-ssd)
- Consider IOPS and throughput limits
- Monitor disk usage and growth patterns

### Backup

This deployment does **not** include automated backups. For production:

1. **Use CloudNativePG** (alternative to this deployment):
   - Built-in backup/restore
   - High availability
   - Connection pooling

2. **External backup tools**:
   - Velero for cluster-level backups
   - pgBackRest for PostgreSQL-specific backups
   - Scheduled Jobs with `pg_dump`

Example backup Job:
```bash
oc create job --from=cronjob/postgres-backup postgres-backup-manual
```

## Using External PostgreSQL

If you have an existing PostgreSQL instance, skip this deployment and:

1. Create the three databases manually
2. Create the database secrets pointing to your external PostgreSQL
3. Deploy only the instance overlay

See [../instance/README.md](../instance/README.md) for details.

## High Availability

This deployment is **single-instance** (1 replica). For production HA:

**Option 1: Use CloudNativePG Operator**
- Automated failover
- Read replicas
- Connection pooling with PgBouncer

**Option 2: Manual StatefulSet HA**
- Increase replicas
- Configure PostgreSQL streaming replication
- Use a Service for automatic failover

## Monitoring

Monitor PostgreSQL health:

```bash
# Pod status
oc get pods -l app=postgresql -n automation-orchestrator

# PostgreSQL logs
oc logs -f postgresql-0 -n automation-orchestrator

# Database connection test
oc exec postgresql-0 -n automation-orchestrator -- pg_isready -U postgres
```

## Troubleshooting

### StatefulSet Not Starting

Check PVC status:
```bash
oc get pvc -n automation-orchestrator
oc describe pvc postgresql-data-postgresql-0 -n automation-orchestrator
```

Common issues:
- No storage class available
- Insufficient storage quota
- Storage provisioner not working

### Database Initialization Job Failed

View Job logs:
```bash
oc logs job/postgresql-init-databases -n automation-orchestrator
```

Common issues:
- PostgreSQL not ready when Job ran
- Incorrect passwords in ConfigMap
- Permission issues (user needs superuser for CREATE DATABASE)

### Connection Refused

Check PostgreSQL readiness:
```bash
oc exec postgresql-0 -n automation-orchestrator -- pg_isready -U postgres
```

Verify Service:
```bash
oc get svc postgresql -n automation-orchestrator
```

## Cleanup

To remove PostgreSQL:

```bash
# Delete the overlay
oc delete -k automation-orchestrator/postgresql/overlays/default

# PVC is not automatically deleted (prevents data loss)
# Manually delete if you want to remove data:
oc delete pvc postgresql-data-postgresql-0 -n automation-orchestrator
```

## Security Considerations

**This deployment is intended for development and testing.**

For production:
- Use Secrets instead of ConfigMaps for passwords
- Enable SSL/TLS connections (configure certificates)
- Configure network policies to restrict access
- Use a dedicated PostgreSQL operator (CloudNativePG)
- Implement regular backup strategies
- Enable PostgreSQL audit logging
- Apply PostgreSQL security hardening

## Additional Resources

- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)
- [Red Hat PostgreSQL Container](https://catalog.redhat.com/software/containers/rhel9/postgresql-15)
- [Automation Orchestrator Database Requirements](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)
- [CloudNativePG Operator](https://cloudnative-pg.io/)
