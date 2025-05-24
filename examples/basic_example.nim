# Basic example of using nim-testkit

import ../src/nimtestkit

# Example types to test
type
  Calculator = object
    memory: float

proc newCalculator(): Calculator =
  Calculator(memory: 0.0)

proc add(c: var Calculator, a, b: float): float =
  result = a + b
  c.memory = result

proc subtract(c: var Calculator, a, b: float): float =
  result = a - b
  c.memory = result

proc getMemory(c: Calculator): float =
  c.memory

# Define test suites
suite "Calculator Unit Tests":
  var calc: Calculator
  
  setup:
    calc = newCalculator()
  
  teardown:
    calc = newCalculator()  # Reset
  
  test "addition works correctly":
    let result = calc.add(2.0, 3.0)
    check result == 5.0
    check calc.getMemory() == 5.0
  
  test "subtraction works correctly":
    let result = calc.subtract(10.0, 3.0)
    check result == 7.0
    check calc.getMemory() == 7.0
  
  test "memory is independent between operations":
    discard calc.add(5.0, 5.0)
    check calc.getMemory() == 10.0
    
    discard calc.subtract(3.0, 1.0)
    check calc.getMemory() == 2.0

suite "Error Handling Tests":
  test "division by zero raises exception":
    expect(DivByZeroDefect):
      let x = 1 div 0
  
  test "skip test example":
    skip("Not implemented yet")
  
  test "test with custom assertion message":
    let value = 42
    check value > 40, "Value should be greater than 40"

# Run all tests
nimTestMain()