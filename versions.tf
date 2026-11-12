terraform {
  required_providers {
    cato = {
      source = "catonetworks/cato"
      # Minimum bound (not an exact pin) so the root module can select newer
      # builds such as the local 1.5.0-prerelease.3 profile-auth build.
      version = ">= 1.5.0-prerelease.3"
    }
  }
  required_version = ">= 1.5"
}
