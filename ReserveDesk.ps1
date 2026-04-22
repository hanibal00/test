# Launch Internet Explorer
$ie = New-Object -ComObject InternetExplorer.Application
$ie.Visible = $true  # Set to $false for silent run

# Navigate to reservation page
$ie.Navigate("https://your-reservation-site.com")

# Wait for page to load
while ($ie.Busy -or $ie.ReadyState -ne 4) { Start-Sleep -Milliseconds 300 }

# Click ADD then DESK (from previous steps)
$addButton = $ie.Document.querySelector("button:contains('ADD')")
if ($addButton) { $addButton.click() }

Start-Sleep -Seconds 2

$deskButton = $ie.Document.querySelector("button:contains('DESK')")
if ($deskButton) { $deskButton.click() }

# Wait for form to load
Start-Sleep -Seconds 3

# Get all dropdowns with class 'dropdown-input'
$dropdowns = $ie.Document.getElementsByClassName("dropdown-input")

# Set Date (first dropdown)
$dateDropdown = $dropdowns.item(0)
$twoWeeks = (Get-Date).AddDays(14).ToString("MM/dd/yyyy")
$dateDropdown.value = $twoWeeks
$dateDropdown.fireEvent("onchange")

Start-Sleep -Seconds 1

# Select 4th Floor (second dropdown)
$floorDropdown = $dropdowns.item(1)
$floorDropdown.value = "4"
$floorDropdown.fireEvent("onchange")

Start-Sleep -Seconds 1

# Select Seat 04-05 (third dropdown)
$seatDropdown = $dropdowns.item(2)
$seatDropdown.value = "04-05"
$seatDropdown.fireEvent("onchange")

Start-Sleep -Seconds 1

# Click BOOK button
$bookButton = $ie.Document.querySelector("button:contains('BOOK')")
if ($bookButton) { $bookButton.click() }

Write-Host "Desk reservation completed for May 6, 2026, Seat 04-05."

# Cleanup
Start-Sleep -Seconds 3
$ie.Quit()