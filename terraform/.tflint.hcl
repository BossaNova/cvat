config {
    module     = false
    # As of tflint v0.15.2 deep_check is only supported for the AWS provider
    force      = false
}

plugin "google" {
    enabled = true
    version = "0.22.1"
    source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "terraform_naming_convention" {
    enabled = true
}

rule "terraform_documented_variables" {
    enabled = true
}

rule "terraform_documented_outputs" {
    enabled = true
}
