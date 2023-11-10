Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to create the network toolbox form
Function Create-NetworkToolboxForm {
    $networkForm = New-Object Windows.Forms.Form
    $networkForm.Text = "Network Toolbox"
    $networkForm.Width = 420
    $networkForm.Height = 300
    $networkForm.BackColor = [System.Drawing.Color]::LightGray

    # Create a group box for Ping
    $pingGroupBox = New-Object Windows.Forms.GroupBox
    $pingGroupBox.Text = "Ping a Host"
    $pingGroupBox.Location = New-Object Drawing.Point(10, 10)
    $pingGroupBox.Width = 390
    $pingGroupBox.Height = 120

    $ipLabel = New-Object Windows.Forms.Label
    $ipLabel.Text = "Enter IP Address:"
    $ipLabel.Location = New-Object Drawing.Point(20, 30)

    $ipTextBox = New-Object Windows.Forms.TextBox
    $ipTextBox.Location = New-Object Drawing.Point(150, 30)
    $ipTextBox.Width = 120

    $pingResultLabel = New-Object Windows.Forms.Label
    $pingResultLabel.Text = ""
    $pingResultLabel.Location = New-Object Drawing.Point(20, 60)
    $pingResultLabel.Width = 320

    $pingButton = New-Object Windows.Forms.Button
    $pingButton.Text = "Ping"
    $pingButton.Location = New-Object Drawing.Point(280, 28)

    $pingButton.Add_Click({
        $targetIP = $ipTextBox.Text
        $ping = Test-Connection -ComputerName $targetIP -Count 4 -ErrorAction SilentlyContinue
        if ($ping) {
            $pingResultLabel.Text = "Ping successful. Response time: $($ping.ResponseTime)ms"
        } else {
            $pingResultLabel.Text = "Ping failed."
        }
    })

    # Create a button for debloating
    $debloatButton = New-Object Windows.Forms.Button
    $debloatButton.Location = New-Object Drawing.Point(20, 150)
    $debloatButton.Size = New-Object Drawing.Size(80, 30)
    $debloatButton.Text = "Debloat"
    $debloatButton.BackColor = [System.Drawing.Color]::DarkRed
    $debloatButton.ForeColor = [System.Drawing.Color]::White

    $debloatButton.Add_Click({
        # Remove Cortana
        Write-Host "Debloating: Removing Cortana"
        Get-AppxPackage -Name Microsoft.549981C3F5F10 | Remove-AppxPackage -ErrorAction SilentlyContinue

        # Remove OneDrive
        Write-Host "Debloating: Removing OneDrive"
        Get-AppxPackage -Name Microsoft.SkyDrive.Desktop | Remove-AppxPackage -ErrorAction SilentlyContinue

        # Uninstall known browsers except Google Chrome
        $browsersToRemove = @(
            "Microsoft.MicrosoftEdge*",
            "Microsoft.InternetExplorer*",
            "Mozilla.*"  # Remove all Mozilla-based browsers, including Firefox
        )
        Write-Host "Debloating: Removing known browsers except Google Chrome"
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -match ($browsersToRemove -join "|") } | ForEach-Object {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
        }

        [System.Windows.Forms.MessageBox]::Show("Debloating completed.", "Debloat Process")
    })

    # Function to get computer specs
    Function Get-ComputerSpecs {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $processorInfo = Get-CimInstance -ClassName Win32_Processor
        $memoryInfo = Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object DeviceID -eq "C:"
        $diskFreeSpaceGB = [math]::Round([double]($diskInfo.FreeSpace) / 1GB, 2)
        $gpuInfo = Get-WmiObject -Class Win32_VideoController

        $computerSpecs = @"
        Operating System: $($osInfo.Caption) ($($osInfo.OSArchitecture))
        Processor: $($processorInfo.Name)
        CPU Cores: $($processorInfo.NumberOfCores)
        Total Memory: $([math]::Round([double]($memoryInfo.Sum) / 1GB, 2)) GB
        Free Disk Space (C:): $diskFreeSpaceGB GB
        GPU: $($gpuInfo.Name)
"@
        [System.Windows.Forms.MessageBox]::Show($computerSpecs, "Computer Specifications")
    }

    # Function to perform a network speed test
    Function Get-NetworkSpeed {
        $downloadSpeedResults = Test-Connection -ComputerName "www.google.com" -Count 3 -ErrorAction SilentlyContinue
        $downloadSpeed = "N/A"

        if ($downloadSpeedResults -is [array] -and $downloadSpeedResults.Count -gt 0) {
            $averageResponseTime = 0
            $count = 0
            foreach ($result in $downloadSpeedResults) {
                $averageResponseTime += $result.ResponseTime
                $count++
            }
            $downloadSpeed = [math]::Round([double]($averageResponseTime / $count), 2)
        }

        # Measure upload speed by sending an HTTP request
        $uploadSpeed = "N/A"
        $uploadSpeedScript = {
            $start = Get-Date
            Invoke-WebRequest -Uri "http://www.google.com" -Method HEAD
            $end = Get-Date
            $elapsed = $end - $start
            $uploadSpeed = [math]::Round([double]$elapsed.TotalMilliseconds, 2)
            $uploadSpeed
        }

        $uploadSpeed = Invoke-Command -ScriptBlock $uploadSpeedScript -ErrorAction SilentlyContinue

        $speedTestResults = @"
        Download Speed: $downloadSpeed ms
        Upload Speed: $uploadSpeed ms
"@
        [System.Windows.Forms.MessageBox]::Show($speedTestResults, "Network Speed Test")
    }

    # Function to check if drivers for a specific hardware category are up to date
    Function Drivers-Check {
        param (
            [string]$HardwareCategory  # Hardware category to check (e.g., "Display")
        )

        $hardwareClass = Get-CimClass -ClassName Win32_PnPEntity
        $drivers = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.PNPClass -eq $HardwareCategory }

        if ($drivers.Count -eq 0) {
            Write-Host "No $HardwareCategory drivers found."
            return
        }

        $outdatedDrivers = @()

        foreach ($driver in $drivers) {
            $driverVersion = $driver.DriverVersion
            $installedDriverVersion = $driver.Version
            $driverName = $driver.Name

            if ($driverVersion -ne $installedDriverVersion) {
                $outdatedDrivers += "$driverName (Installed: $installedDriverVersion, Latest: $driverVersion)"
            }
        }

        if ($outdatedDrivers.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("All $HardwareCategory drivers are up to date.", "Drivers Check")
        } else {
            Write-Host "Outdated $HardwareCategory drivers:"
            $outdatedDrivers
        }
    }

    # Create a button for getting computer specs
    $getSpecsButton = New-Object Windows.Forms.Button
    $getSpecsButton.Location = New-Object Drawing.Point(20, 200)
    $getSpecsButton.Size = New-Object Drawing.Size(100, 30)
    $getSpecsButton.Text = "PC Specs"
    $getSpecsButton.BackColor = [System.Drawing.Color]::SteelBlue
    $getSpecsButton.ForeColor = [System.Drawing.Color]::White

    $getSpecsButton.Add_Click({
        Get-ComputerSpecs
    })

    # Create a button for network speed test
    $networkSpeedButton = New-Object Windows.Forms.Button
    $networkSpeedButton.Location = New-Object Drawing.Point(140, 200)
    $networkSpeedButton.Size = New-Object Drawing.Size(100, 30)
    $networkSpeedButton.Text = "Speed Test"
    $networkSpeedButton.BackColor = [System.Drawing.Color]::SteelBlue
    $networkSpeedButton.ForeColor = [System.Drawing.Color]::White

    $networkSpeedButton.Add_Click({
        Get-NetworkSpeed
    })

    # Create a button for checking drivers
    $driversCheckButton = New-Object Windows.Forms.Button
    $driversCheckButton.Location = New-Object Drawing.Point(260, 200)
    $driversCheckButton.Size = New-Object Drawing.Size(100, 30)
    $driversCheckButton.Text = "Drivers Check"
    $driversCheckButton.BackColor = [System.Drawing.Color]::SteelBlue
    $driversCheckButton.ForeColor = [System.Drawing.Color]::White

    $driversCheckButton.Add_Click({
        Drivers-Check -HardwareCategory "Display"
    })

    # Add controls to the group box
    $pingGroupBox.Controls.Add($ipLabel)
    $pingGroupBox.Controls.Add($ipTextBox)
    $pingGroupBox.Controls.Add($pingButton)
    $pingGroupBox.Controls.Add($pingResultLabel)

    # Add controls to the networkForm
    $networkForm.Controls.Add($pingGroupBox)
    $networkForm.Controls.Add($debloatButton)
    $networkForm.Controls.Add($getSpecsButton)
    $networkForm.Controls.Add($networkSpeedButton)
    $networkForm.Controls.Add($driversCheckButton)

    $networkForm.ShowDialog()
}

# Create the network toolbox form as the main window
Create-NetworkToolboxForm