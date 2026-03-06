
# AI First-Contact Detector Pattern

## Concept

A scannable specification telling an AI model what structural
opportunities to look for in a repository, and where to write
results, without touching runtime code. Separates AI-layer
metadata from runtime artifacts by convention.

## P7 Structure Mapping

+------------------------+------------------------------------------------+
| Generic concept        | Protocol-7 equivalent                          |
|------------------------|------------------------------------------------|
| runtime boundary       | bin/, modules/, data/lib-path/pm/AMOS7/        |
| AI metadata layer      | data/asc/what-AI-thinks/                       |
| task accumulation      | data/yaml/coding-tasks/, data/yaml/indexes/    |
| model memory           | data/ai-mem/claude/, data/ai-mem/kimi/         |
| detector output        | data/yaml/coding-tasks/<generated-task>.yaml   |
+------------------------+------------------------------------------------+

## Future Use

When knowledge base format and scanning rules are upgraded, this pattern can
define how models self-direct documentation and onboarding gap detection
across the repository without human-specified task lists.

## Status

Stub. Expand during kb format upgrade.

#,,,,,,.,,,.,,,.,,.,.,,..,..,,..,,.,.,.,.,...,..,,...,.,.,.,.,.,.,...,.,,,..,,
#H2QW3KJQSUFA6HZDUY5ZY5L3JOHMJPLXRX4EXPRVGLXQEFA374LWNT4ZCFNZW6F7PC2AGNPL5SBVY
#\\\|J43VWRRTSCQZLPL3RRJ3QKJLCJLM4BEZP2K77LFS5PDSA3QCGSN \ / AMOS7 \ YOURUM ::
#\[7]WOK56EYTTXAC5UASKK36DPUNYIXYKROKFSGLDA344O2URYSWQOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
