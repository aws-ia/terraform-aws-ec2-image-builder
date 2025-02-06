run "unit_test" {
  command = plan
  module {
    source = "./examples/windows"
  }
}

run "e2e_test" {
  command = apply
  module {
    source = "./examples/windows"
  }
}