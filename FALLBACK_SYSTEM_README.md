# Comprehensive Fallback System

## Overview

This project includes a comprehensive fallback system designed to handle both database migration failures and application runtime issues. The system provides multiple layers of protection and recovery options.

## Components

### 1. Migration Fallback System (`migration_fallback.sh`)
Handles database migration failures and provides rollback capabilities.

**Features:**
- Automatic backup creation before migrations
- Migration validation
- Rollback script generation
- Emergency recovery procedures

**Usage:**
```bash
# Show available commands
./migration_fallback.sh

# Create full backup
./migration_fallback.sh backup

# Validate a migration file
./migration_fallback.sh validate path/to/migration.sql

# Create rollback script
./migration_fallback.sh rollback path/to/migration.sql
```

### 2. Database Backup & Restore Utility (`database_backup_restore.sh`)
Manages database backups and provides restoration capabilities.

**Features:**
- Schema-only backups
- Essential data backups
- Restore script generation
- Backup validation and cleanup

**Usage:**
```bash
# Create full backup
./database_backup_restore.sh backup

# Backup schema only
./database_backup_restore.sh schema

# List available backups
./database_backup_restore.sh list

# Clean old backups
./database_backup_restore.sh clean
```

### 3. Emergency Recovery System (`emergency_recovery.sh`)
Handles critical system failures and provides emergency recovery procedures.

**Features:**
- System health checks
- Emergency app rollback
- Emergency database rollback
- Recovery reporting

**Usage:**
```bash
# System health check
./emergency_recovery.sh health

# Emergency app rollback
./emergency_recovery.sh app

# Full emergency recovery (requires --emergency flag)
./emergency_recovery.sh --emergency full
```

### 4. App Fallback System (`lib/services/app_fallback_system.dart`)
Runtime fallback system for the Flutter application.

**Features:**
- Offline mode detection and handling
- Supabase connectivity monitoring
- Data caching and synchronization
- Graceful degradation UI components

**Integration:**
```dart
// Initialize in main.dart
await AppFallbackSystem().initialize();

// Use in widgets
FallbackWrapper(
  child: YourWidget(),
  offlineWidget: OfflineWidget(),
  errorWidget: ErrorWidget(),
)
```

## Configuration

The system is configured via `fallback_config.toml`:

```toml
[migration_fallback]
auto_backup_enabled = true
backup_retention_days = 30

[app_fallback]
offline_mode_enabled = true
connectivity_check_interval = 30

[emergency_recovery]
emergency_contacts = ["admin@locallekker.com"]
```

## Directory Structure

```
project_root/
├── migration_fallback.sh              # Migration fallback utility
├── database_backup_restore.sh         # Database backup utility
├── emergency_recovery.sh              # Emergency recovery system
├── fallback_config.toml               # Configuration file
├── database_backups/                  # Backup storage directory
│   ├── schema_backup_*.sql
│   ├── essential_data_backup_*.sql
│   └── emergency_*.sql
├── lib/services/
│   └── app_fallback_system.dart       # App runtime fallback
└── supabase/migrations/               # Database migrations
```

## Recovery Procedures

### Database Migration Failure

1. **Immediate Response:**
   ```bash
   ./migration_fallback.sh rollback failed_migration.sql
   ```

2. **If Rollback Fails:**
   ```bash
   ./emergency_recovery.sh --emergency database
   ```

3. **Complete Recovery:**
   ```bash
   ./database_backup_restore.sh restore
   ```

### Application Runtime Failure

1. **Check System Health:**
   ```bash
   ./emergency_recovery.sh health
   ```

2. **App-Level Recovery:**
   ```bash
   ./emergency_recovery.sh app
   ```

3. **Generate Recovery Report:**
   ```bash
   ./emergency_recovery.sh report
   ```

## Monitoring and Alerts

The system includes monitoring capabilities:

- **Migration Monitoring:** Tracks migration success/failure
- **Connectivity Monitoring:** Detects network and service issues
- **Cache Monitoring:** Monitors cached data integrity
- **Error Tracking:** Logs and reports application errors

## Testing

### Testing the Fallback System

1. **Enable Testing Mode:**
   ```toml
   [testing]
   testing_mode_enabled = true
   ```

2. **Run Test Scenarios:**
   - Network failure simulation
   - Service unavailability testing
   - Cache corruption testing

### Validation Commands

```bash
# Validate all backup files
find database_backups -name "*.sql" -exec ./database_backup_restore.sh validate {} \;

# Test connectivity monitoring
flutter run --dart-define=TEST_FALLBACK=true

# Validate migration files
./migration_fallback.sh validate supabase/migrations/*.sql
```

## Best Practices

### Backup Strategy
- Always create backups before major migrations
- Keep multiple backup types (schema + data)
- Test backup restoration regularly
- Store backups in secure locations

### Error Handling
- Use try-catch blocks around critical operations
- Implement graceful degradation
- Provide user feedback for fallback states
- Log all errors with context

### Monitoring
- Set up alerts for critical failures
- Monitor system health regularly
- Keep recovery procedures updated
- Document all changes and incidents

## Emergency Contacts

- **Primary Admin:** admin@locallekker.com
- **Technical Support:** support@locallekker.com
- **Emergency Hotline:** +27-XX-XXX-XXXX

## Documentation Links

- [Migration Guide](docs/migration_fallback_guide.md)
- [App Fallback Guide](docs/app_fallback_guide.md)
- [Emergency Recovery Procedures](docs/emergency_recovery.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## Quick Reference

### Most Common Commands

```bash
# Create backup before migration
./migration_fallback.sh backup

# Health check
./emergency_recovery.sh health

# Full system backup
./database_backup_restore.sh backup

# Emergency recovery
./emergency_recovery.sh --emergency full
```

### App Integration

```dart
// Initialize fallback system
await AppFallbackSystem().initialize();

// Use fallback wrapper
FallbackWrapper(
  child: MainApp(),
  offlineWidget: OfflineScreen(),
)
```

This fallback system ensures business continuity and provides multiple recovery options for various failure scenarios.