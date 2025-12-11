# Security Guidelines

## ⚠️ Sensitive Information - DO NOT COMMIT

This repository contains Infrastructure as Code and documentation for an Azure monitoring lab. The following types of sensitive information should **NEVER** be committed to version control:

### 🔒 What to Keep Private

1. **Subscription IDs**
   - Azure subscription GUIDs
   - Subscription names containing organizational information

2. **Authentication Keys & Tokens**
   - Application Insights instrumentation keys
   - Application Insights connection strings
   - Storage account access keys
   - Redis cache access keys
   - Service Bus connection strings
   - Container Registry passwords

3. **Resource IDs**
   - Full Azure resource IDs (contain subscription IDs)
   - Managed identity client IDs
   - Application IDs
   - Tenant IDs

4. **FQDNs with Unique Identifiers**
   - Azure Bastion FQDNs (contain unique GUIDs)
   - Any FQDN that includes deployment-specific unique identifiers

5. **Deployment Outputs**
   - Files in `.azure/` directory
   - Any JSON/text files containing deployment outputs
   - Terraform state files (if using Terraform)

### ✅ What's Safe to Commit

1. **Infrastructure Code**
   - Bicep templates
   - ARM templates
   - Parameter file structures (with placeholder values)

2. **Documentation**
   - Architecture diagrams
   - Setup instructions with placeholders
   - Configuration examples using `<placeholder>` syntax

3. **Application Code**
   - Java source code
   - Dockerfiles
   - Maven POM files
   - Application configuration templates

4. **Scripts**
   - Deployment scripts
   - Build scripts
   - Initialization scripts

### 🛡️ Best Practices

1. **Use Placeholders in Documentation**
   ```bash
   # ❌ Bad
   az acr login --name acrmonlabcc01
   export APP_INSIGHTS_KEY="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
   
   # ✅ Good
   az acr login --name <your-acr-name>
   export APP_INSIGHTS_KEY="<your-instrumentation-key>"
   ```

2. **Store Secrets in Azure Key Vault**
   - All connection strings and keys should be stored in Key Vault
   - Reference secrets from Key Vault in application configuration
   - Use managed identities for authentication

3. **Use Environment Variables**
   - Never hardcode secrets in application code
   - Load secrets from environment variables or Key Vault at runtime

4. **Protect Local Files**
   - Add `.azure/`, `*.env`, and other sensitive files to `.gitignore`
   - Review staged changes before committing: `git diff --cached`

5. **GitHub Secret Scanning**
   - GitHub automatically scans for exposed secrets
   - If notified, rotate compromised credentials immediately
   - Delete the deployment and redeploy if keys are exposed

### 📋 .gitignore Entries

Ensure your `.gitignore` includes:

```gitignore
# Azure deployment outputs
.azure/
*.azureauth
*.publishsettings

# Environment files
.env
.env.local
*.env

# Terraform state (if applicable)
*.tfstate
*.tfstate.backup
.terraform/

# Local configuration
local.settings.json
appsettings.Development.json

# IDE files
.vscode/settings.json
.idea/
*.iml
```

### 🚨 If Secrets Are Exposed

If you accidentally commit sensitive information:

1. **Immediately Rotate Credentials**
   ```bash
   # Regenerate Application Insights keys
   az monitor app-insights component update --app <app-name> --resource-group <rg-name>
   
   # Regenerate storage keys
   az storage account keys renew --account-name <storage-name> --key primary
   
   # Regenerate Service Bus keys
   az servicebus namespace authorization-rule keys renew \
     --namespace-name <namespace> --name RootManageSharedAccessKey --key PrimaryKey
   ```

2. **Remove from Git History**
   ```bash
   # Use BFG Repo-Cleaner or git filter-branch
   # WARNING: This rewrites history - coordinate with team
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch <sensitive-file>' \
     --prune-empty --tag-name-filter cat -- --all
   
   # Force push (requires coordination)
   git push origin --force --all
   ```

3. **Contact GitHub Support**
   - If the repository is public, contact GitHub to purge cached views
   - Request removal from GitHub's search index

### 📚 Additional Resources

- [Azure Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)
- [Managing Secrets in Azure](https://docs.microsoft.com/azure/security/fundamentals/secrets-best-practices)
- [GitHub Secret Scanning](https://docs.github.com/code-security/secret-scanning)
- [Removing Sensitive Data from Git](https://docs.github.com/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

**Remember**: When in doubt, don't commit it. Secrets can always be retrieved from Azure Key Vault after deployment.
