run "unit_test" {
  command = plan
  module {
    source = "./examples/linux"
  }
}

run "e2e_test" {
  command = apply
  module {
    source = "./examples/linux"
  }
}