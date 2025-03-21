def create_9x9_harmonic_matrix():
    """Create a 9x9 harmonic matrix with mod-13 values"""
    matrix = [[0 for _ in range(9)] for _ in range(9)]
    
    # Fill with mod-13 values
    for r in range(9):
        for c in range(9):
            node_id = r * 9 + c
            matrix[r][c] = {
                'id': node_id,
                'mod13_value': node_id % 13,
                'connections': []
            }
    
    # Create connections based on harmonic relationships
    for r in range(9):
        for c in range(9):
            node = matrix[r][c]
            
            # Connect to each node's 5th harmonic (based on mod-13 value)
            harmonic_value = (node['mod13_value'] * 5) % 13
            
            # Find all nodes with matching harmonic value
            for tr in range(9):
                for tc in range(9):
                    if matrix[tr][tc]['mod13_value'] == harmonic_value:
                        node['connections'].append((tr, tc))
    
    return matrix