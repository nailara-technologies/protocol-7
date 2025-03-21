const healingProcess = () => {
                step++;
                
                // Update visual effects during healing
                document.querySelectorAll('.cube-face').forEach(face => {
                    face.style.borderWidth = '3px';
                    setTimeout(() => face.style.borderWidth = '2px', 250);
                });
                
                // Gradually apply pattern
                if (step < totalSteps) {
                    // Apply partial pattern
                    const patternTest = PATTERN_TESTS[currentMode];
                    const cssClass = MODES[currentMode].cssClass;
                    let activeCount = 0;
                    
                    cells.forEach(cell => {
                        const row = parseInt(cell.dataset.row);
                        const col = parseInt(cell.dataset.col);
                        
                        if (patternTest(row, col) && Math.random() < step/totalSteps) {
                            cell.className = cssClass;
                            activeCount++;
                        }
                    });
                    
                    document.getElementById('active-count').textContent = activeCount;
                    currentProcess = setTimeout(healingProcess, 500);
                } else {
                    // Final healing - apply full pattern
                    applyMode(currentMode);
                    
                    // Final pulse to indicate completion
                    const energyBeams = document.querySelectorAll('.energy-beam');
                    energyBeams.forEach(beam => {
                        beam.style.background = 'linear-gradient(to top, rgba(64, 255, 128, 0), rgba(64, 255, 128, 0.7))';
                        setTimeout(() => {
                            beam.style.background = '';
                        }, 500);
                    });
                }
            };
            
            healingProcess();
        });

        // Initial mode setup
        applyMode("CUBE");
    </script>
</body>
</html>
