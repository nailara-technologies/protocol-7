#!/usr/bin/env python3
"""
Test inference on regex pattern correction using smollm-360M model
"""

import sys

try:
    from llama_cpp import Llama
except ImportError:
    print("ERROR: llama-cpp-python not installed")
    print("Install with: pip install llama-cpp-python")
    sys.exit(1)

# Model path
MODEL_PATH = "/mnt/m/HuggingFaceTB/smollm-360M-instruct-v0.2-Q8_0-GGUF/smollm-360m-instruct-add-basics-q8_0.gguf"

# Test code
TEST_CODE = """#!/usr/bin/perl
# These should be converted from s/// to s|||
$text =~ s/^- \\[ \\]/- [x]/;
$path =~ s|^$scan_dir||;

# Return value corrections
sub validate_input {
    return 1 if $input;
    return 0;
}"""

PROMPT = f"""You are a Perl code style expert. Analyze this code and suggest corrections:

1. Convert s/// (slash delimiters) to s||| (pipe delimiters) when pipes aren't in the pattern
2. Keep s||| (pipe delimiters) when pipes are already in the pattern
3. Replace 'return 1' with 'return TRUE' in subroutines
4. Replace 'return 0' with 'return FALSE' in subroutines

Code to fix:
{TEST_CODE}

Output the corrected code:"""

def test_inference():
    """Test inference with smollm model"""
    print("Loading model...")
    try:
        llm = Llama(
            model_path=MODEL_PATH,
            n_ctx=512,
            n_threads=4,
            verbose=False
        )
        print("✓ Model loaded successfully")
    except Exception as e:
        print(f"ERROR loading model: {e}")
        return False

    print("\nRunning inference...")
    try:
        response = llm(
            PROMPT,
            max_tokens=256,
            temperature=0.2,
            top_p=0.9,
            echo=False
        )

        output = response['choices'][0]['text']
        print("\nModel output:")
        print("-" * 60)
        print(output)
        print("-" * 60)

        # Validate output contains expected corrections
        checks = {
            "Uses s||| delimiters": "s|" in output,
            "TRUE keyword": "TRUE" in output,
            "FALSE keyword": "FALSE" in output,
        }

        print("\nValidation:")
        all_pass = True
        for check, result in checks.items():
            status = "✓" if result else "✗"
            print(f"  {status} {check}")
            if not result:
                all_pass = False

        return all_pass

    except Exception as e:
        print(f"ERROR during inference: {e}")
        return False

if __name__ == "__main__":
    success = test_inference()
    sys.exit(0 if success else 1)

#,,..,..,,..,,,,.,...,.,.,,,,,,,.,...,,..,,,,,..,,...,...,..,,.,,,,,,,.,.,...,
#67MPEAAOSGYTRRCABILE5VVSCQ7PQNJAYFY73AH526Y5HWPROT4QFOKBMHRQBFKVHFG63AGAXFDQQ
#\\\|MHNHZ6BPHRKSSO3ZQGK3MABR445PVAXWC6H727XRID7WNN5WYNT \ / AMOS7 \ YOURUM ::
#\[7]UTRY7Y4WMKEGE5I3RWWFBO4T4LT6GGYMLFJNG776GJUIJ6LLIOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
