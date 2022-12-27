# ssl_checker

This repository contains code that is intended to check individual domains for SSL certificate expiration. This is intended to work with several AWS components: Lambda, an API gateway, and an SNS topic. This also includes IaC components intended to be deployed with Terraform, allowing me to do nearly all of this setup from Terraform. I'll explain each step of the way and provide screenshots where applicable.

I have all of the explanation over here in the [solution.md](https://github.com/GittyUpPartner/ssl_checker/blob/main/solution.md) file.
