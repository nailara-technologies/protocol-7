# Repository Keyword Paths

## Overview

Protocol-7 now supports portable repository keyword paths that automatically resolve to the correct directory based on the execution environment (local or Claude).

## Keywords

- `[protocol-7]` - Resolves to the protocol-7 repository root
  - Local: `/home/user/protocol-7`
  - Claude: `/data/projects/protocol-7`

- `[workspace-transfer]` - Resolves to the workspace-transfer repository root
  - Local: `/home/user/workspace-transfer`
  - Claude: `/data/projects/workspace-transfer`

## Examples

### YAML Task Files

Instead of using absolute paths like:
```yaml
path: /home/user/protocol-7/data/yaml/coding-tasks/my-task.yaml
```

Use portable keywords:
```yaml
path: [protocol-7]/data/yaml/coding-tasks/my-task.yaml
```

### In Perl Code

#### Load YAML files with keyword paths
```perl
my $task_data = <[base.yaml.load_keyword_path]>->(
    '[protocol-7]/data/yaml/coding-tasks/my-task.yaml'
);
```

#### Open files with keyword paths
```perl
my $fh = <[base.path.open]>->('[protocol-7]/data/yaml/some-file.txt');
```

#### Convert absolute paths to keywords
```perl
my $keyword_path = <[base.path.to_keywords]->(
    '/home/user/protocol-7/data/yaml/coding-tasks/task.yaml'
);
# Returns: [protocol-7]/data/yaml/coding-tasks/task.yaml
```

#### Resolve keyword paths to absolute paths
```perl
my $abs_path = <[base.path.resolve_keywords]->('[protocol-7]/data/yaml/file.yaml');
# Returns: /home/user/protocol-7/data/yaml/file.yaml (or /data/projects/... in Claude)
```

#### Detect current environment
```perl
my $env = <[base.env.detect_environment]>;
print $env->{protocol7_root};      # Get protocol-7 root path
print $env->{workspace_root};      # Get workspace-transfer root path
print $env->{environment_type};    # 'local', 'claude', or 'unknown'
```

## Benefits

1. **Portability**: Task files and configuration work in both local and Claude environments
2. **Readability**: Keyword paths are more concise and self-documenting
3. **Maintainability**: No need to update paths when migrating between environments
4. **Automatic Detection**: Environment detection is automatic based on directory structure

## Environment Detection

The system detects the environment by checking for:

1. Environment variables: `PROTOCOL7_ROOT`, `WORKSPACE_TRANSFER_ROOT`
2. Local paths: `/home/user/protocol-7`, `/home/user/workspace-transfer`
3. Claude paths: `/data/projects/protocol-7`, `/data/projects/workspace-transfer`
4. Current working directory relative paths

The first match found is used.

## Generated Indexes

Task indexes (todos-index.yaml, workspace-transfer-index.yaml) are now generated with keyword-based paths automatically. When regenerating indexes, the conversion happens transparently.

Example generated index entry:
```yaml
- title: My Task
  path: [protocol-7]/data/yaml/coding-tasks/my-task.yaml
  file: my-task.yaml
  type: coding-task
```

## Implementation Details

### Modules

- `base.env.detect_environment` - Environment and path detection
- `base.path.resolve_keywords` - Convert keywords to absolute paths
- `base.path.to_keywords` - Convert absolute paths to keywords
- `base.path.open` - File opening with keyword support
- `base.yaml.load_keyword_path` - YAML loading with keyword support
- `workflow.scan_yaml_tasks` - Updated to generate keyword paths
- `workflow.extract_workspace_todos` - Updated to use keyword paths
