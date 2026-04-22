# Load Selenium WebDriver
Add-Type -Path "C:\Selenium\WebDriver.dll"

# Set up Chrome options
$chromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
$chromeOptions.AddArgument("--start-maximized")

# Start Chrome driver
$driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver("C:\Selenium\", $chromeOptions)

try {
    $driver.Navigate().GoToUrl("https://your-reservation-site.com")

    # Click ADD then DESK
    $driver.FindElement([OpenQA.Selenium.By]::XPath("//button[contains(text(),'ADD')]")).Click()
    Start-Sleep -Seconds 2
    $driver.FindElement([OpenQA.Selenium.By]::XPath("//button[contains(text(),'DESK')]")).Click()

    Start-Sleep -Seconds 2

    # Get all dropdowns by class name
    $dropdowns = $driver.FindElements([OpenQA.Selenium.By]::ClassName("dropdown-input"))

    # Set Date (2 weeks from today: May 6, 2026)
    $dropdowns[0].SendKeys("05/06/2026")
    $dropdowns[0].SendKeys([OpenQA.Selenium.Keys]::Enter)

    Start-Sleep -Seconds 1

    # Select 4th Floor
    $dropdowns[1].SendKeys("4")
    $dropdowns[1].SendKeys([OpenQA.Selenium.Keys]::Enter)

    Start-Sleep -Seconds 1

    # Select Seat 04-05
    $dropdowns[2].SendKeys("04-05")
    $dropdowns[2].SendKeys([OpenQA.Selenium.Keys]::Enter)

    Start-Sleep -Seconds 1

    # Click BOOK
    $driver.FindElement([OpenQA.Selenium.By]::XPath("//button[contains(text(),'BOOK')]")).Click()

    Write-Host "Reservation completed for Seat 04-05 on May 6, 2026."

} finally {
    Start-Sleep -Seconds 3
    $driver.Quit()
}