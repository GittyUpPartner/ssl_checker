# ssl_checker

This repository contains code that is intended to check individual domains for SSL certificate expiration. This is intended to work with several AWS components: Lambda, an API gateway, and an SNS topic. I'll explain each step of the way and provide screenshots where applicable. This does include IaC components intended to be deployed with Terraform. I have all of the relevant stuff over here in the [solution.md](https://github.com/GittyUpPartner/ssl_checker/blob/main/solution.md) file.
