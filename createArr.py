import numpy as np
import subprocess
import json

testCount = 10
passed = 0
cycles = []
for i in range(testCount):
    # Generate a 6x5 array with random decimal values between 0 and 1
    A = np.random.randint(1, 10, size=(6, 5))

    # Generate a 5x7 array with random decimal values between 0 and 1
    B = np.random.randint(1, 10, size = (5, 7))

    print("Array A: \n", A)
    print("Array B: \n", B)

    FMT = {"numeric_type": "bitnum", "is_signed": False, "width": 32}

    data = {
        "arr1":   {"data": A.tolist(), "format": FMT},
        "arr2":   {"data": B.tolist(), "format": FMT},
        "arrOut": {"data": np.zeros((A.shape[0], B.shape[1]), int).tolist(),
                "format": FMT},
    }

    with open("matMulTestData.json", "w") as f:
        json.dump(data, f, indent=2)

    result = subprocess.run(
        ["fud2", "matMul.futil",
        "-s", "sim.data=matMulTestData.json",
        "--to", "dat", "--through", "icarus"],
        capture_output=True, text=True, check=True,
    )

    out = json.loads(result.stdout)
    print("out: ", out)
    got = np.array(out["memories"]["arrOut"])
    expected = A @ B

    if np.array_equal(got, expected):
        print("PASS")
        passed += 1
        cycles.append(out["cycles"])
    else:
        print("FAIL")
        print("got:\n", got)
        print("expected:\n", expected)
        print("diff:\n", got - expected)
print (f"Tests passed: {passed}/10")
print (f"Cycle count per test: {cycles}")