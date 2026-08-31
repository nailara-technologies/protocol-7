/* elf-checksum.js — AMOS7 ELF-7 checksum (harmonic, division-by-13-tuned),
 * ported from AMOS7::CHKSUM::ELF (data/lib-path/pm/AMOS7/CHKSUM/ELF.pm),
 * extracted from data/backup/html/de/jobcenter.application_tracker.html.
 *
 * usage:
 *   <script src="/shared/templates/components/elf-checksum.js"></script>
 *   <script>
 *     var cksum = P7.checksum.generate64('Acme GmbH|Backend Engineer');
 *     P7.checksum.match(cksum, otherCksum);
 *   </script>
 */
(function (global) {
    'use strict';

    /**
     * ELF-7 Checksum Algorithm (AMOS7 JavaScript Port)
     *
     * Harmonic checksum algorithm using division by 13 properties.
     * Supports multiple modes (4, 7) and configurable shift bits.
     *
     * @param {string} str - Input string to checksum
     * @param {number} start_sum - Starting checksum value (for continuation)
     * @param {number} elf_mode - ELF mode: 4 (stable) or 7 (entropic)
     * @param {number} shift_bits - Right shift bits (default: 13 for AMOS7)
     * @returns {number} 32-bit unsigned integer checksum
     */
    function elf7_checksum(str, start_sum, elf_mode, shift_bits) {
        start_sum  = start_sum  === undefined ? 0  : start_sum;
        elf_mode   = elf_mode   === undefined ? 7  : elf_mode;
        shift_bits = shift_bits === undefined ? 13 : shift_bits;

        var overflow_threshold = 0xFE000000;  // AMOS-13-ELF-7 threshold
        var result = start_sum >>> 0;         // Ensure unsigned 32-bit
        var carryover;

        var left = elf_mode;                  // Left shift value
        var right = shift_bits;               // Right shift value
        var shift_limit = (~result >>> 0) >>> 4;
        var actual_left = left;

        // Process each character
        for (var i = 0; i < str.length; i++) {
            var char = str.charCodeAt(i);

            // Reset shift to prevent entropy loss
            if (actual_left > 4 && result >= shift_limit) {
                actual_left = 4;
            }

            // Core ELF algorithm
            result = ((result << actual_left) + char) >>> 0;

            // Handle overflow
            carryover = result & overflow_threshold;
            if (carryover) {
                result ^= carryover >>> right;
            }
            result &= ~carryover;
        }

        return result;
    }

    /**
     * Normalize string for checksum comparison
     * Removes common variations that should be treated as identical
     *
     * @param {string} str - Input string
     * @returns {string} Normalized string
     */
    function normalize_for_checksum(str) {
        return str
            .toLowerCase()
            .replace(/\s+/g, ' ')                    // Normalize whitespace
            .replace(/[^a-z0-9\s]/g, '')              // Remove special chars
            .replace(/\b(gmbh|ag|llc|inc|corp|ltd|limited|plc|sa|se|kg|ohg|gbr)\b/gi, '')
            .trim();
    }

    /**
     * Generate 64-bit checksum from string (mode 4 + mode 7)
     * Returns high/low 32-bit values for quad-integer encoding
     *
     * @param {string} str - Input string
     * @returns {Object} {high: number, low: number, combined: string}
     */
    function generate_checksum_64(str) {
        var norm = normalize_for_checksum(str);

        // Mode 4: Stable, consistent for similar strings
        var cksum_m4 = elf7_checksum(norm, 0, 4, 13);

        // Mode 7: Entropic, differentiates similar strings
        var cksum_m7 = elf7_checksum(norm, 0, 7, 13);

        // Format as 18-digit string (9 digits each, zero-padded)
        // Compatible with quad-integer BASE32 encoding
        return {
            high: cksum_m4,
            low: cksum_m7,
            combined: String(cksum_m4).padStart(9, '0') +
                     String(cksum_m7).padStart(9, '0')
        };
    }

    /**
     * Check if two checksum objects match
     *
     * @param {Object} cksum1 - First checksum {high, low}
     * @param {Object} cksum2 - Second checksum {high, low}
     * @returns {boolean} True if checksums match
     */
    function checksums_match(cksum1, cksum2) {
        return cksum1.high === cksum2.high &&
               cksum1.low === cksum2.low;
    }

    global.P7 = global.P7 || {};
    global.P7.checksum = {
        elf7: elf7_checksum,
        normalize: normalize_for_checksum,
        generate64: generate_checksum_64,
        match: checksums_match
    };
})(window);
