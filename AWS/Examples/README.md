# **Terraform & PowerShell Deployment Logic**

This Terraform configuration and PowerShell scripts automate the deployment, configuration, monitoring integration, and decommissioning of a Windows-based EC2 instance in AWS.

---

## **Terraform (`main.tf`) Logic**

### **1. Provider & Data Source Definition**
- Defines AWS as the provider and sets the region dynamically via `var.region`.
- Uses `data "aws_ami"` to look up the latest AMI based on filters provided (`var.amiregexid` and `var.amiregexname`).

### **2. EC2 Instance Creation**
- Creates an EC2 instance using the AMI found above.
- Key attributes:
  - **`iam_instance_profile`**: Assigns an IAM role.
  - **`instance_type`**: Specifies the VM size.
  - **`key_name`**: SSH key for remote access.
  - **`subnet_id`**: Specifies where in the VPC this instance is placed.
  - **`tags`**: Metadata for tracking ownership (`Owner`, `CreatedBy`, `Name`).
  - **`vpc_security_group_ids`**: Security rules for the instance.

### **3. Bootstrapping with User Data**
- Runs `Scripts/UserData.ps1` on instance startup to configure WinRM and set up basic system settings.

### **4. Provisioners for Configuration**
#### **`provisioner "local-exec"`**
- Runs on the machine executing Terraform (not on the EC2 instance).
- Used for:
  - Cleanup when the instance is destroyed (`Decom-Server.ps1`).
  - Executing pre- and post-configuration scripts (`Start-PreConfig.ps1`, `Start-PostConfig.ps1`).
  - Deploying desired state configuration (`LCM-Configuration.ps1`, `DSC-Configuration.ps1`).

#### **`provisioner "file"`**
- Uploads `FormatDisks.ps1` to the instance for formatting disks.

#### **`provisioner "remote-exec"`**
- Executes PowerShell on the remote machine over WinRM.
- Runs `FormatDisks.ps1` on the instance after it boots.

---

## **PowerShell Script Logic**
Each PowerShell script performs different setup and configuration tasks.

### **1. `UserData.ps1` (Runs on First Boot)**
- Sets up logging in `C:\Windows\Temp\Azure DevOps`.
- Configures **WinRM** for remote management.
- Updates the **hosts file** with agent and repo server IPs.
- Ensures the **system is ready for remote execution**.

---

### **2. `Start-PreConfig.ps1` (Runs After Instance Boot)**
- Logs operations to `C:\Windows\Temp\Azure DevOps\PreConfiguration.log`.
- **Renames the computer** (`Rename-Computer -NewName $ServerName`).
- **Joins the domain** using admin credentials.
- **Configures auto-login**
- Reboots if needed.

---

### **3. `Start-PostConfig.ps1` (Final System Setup)**
- Moves the instance to the correct **Active Directory OU**.
- Adds it to the **WSUS groups** for updates.
- Registers the server with **McAfee ePO** for security monitoring.
- Registers the server in **SolarWinds** for performance monitoring.

---

### **4. `Decom-Server.ps1` (Runs When Destroying the Instance)**
- Removes the server from **Active Directory**.
- Deletes **DNS entries** to prevent conflicts.
- Removes from **McAfee ePO** and **SolarWinds**.

---

### **5. `DSC-Configuration.ps1` (Desired State Configuration)**
- Uses **PowerShell DSC** to:
  - Install **Chocolatey** for package management.
  - Add a Chocolatey package source.
  - Install **Notepad++**.

---

## **Overall Flow**
1. **Terraform creates the EC2 instance.**
2. **UserData.ps1 runs at boot** to configure WinRM and networking.
3. **Terraform provisioners execute the configuration scripts:**
   - `Start-PreConfig.ps1`: Renames, joins the domain.
   - `Start-PostConfig.ps1`: Finalizes configuration, registers with monitoring tools.
   - `DSC-Configuration.ps1`: Applies configuration management.
4. **When the instance is destroyed, `Decom-Server.ps1` cleans up.**

---

## **Key Takeaways**
- **Automates Windows EC2 deployment.**
- **Configures domain join, security tools, monitoring, and patching.**
- **Uses PowerShell for deep system configuration.**
- **Uses Terraform provisioners for automation.**