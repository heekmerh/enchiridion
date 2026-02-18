/**
 * Enchiridion Referral System - Google Sheets Backend
 * 
 * Instructions:
 * 1. Create a Google Sheet.
 * 2. In the sheet, create three tabs: "Partners", "ActivityLog", and "PayoutSettings".
 *    - "Partners" Columns: Username, Password, Name, ReferralCode, Email Address, DateJoined
 * 3. Go to Extensions > Apps Script.
 * 4. Paste this code.
 * 5. Set up a "Trigger": 
 *    - Click the clock icon (Triggers) in the left sidebar.
 *    - Click "+ Add Trigger".
 *    - Choose "onPartnerRowAdded" for the function.
 *    - Choose "From spreadsheet" for event source.
 *    - Choose "On change" for event type.
 * 6. Click Deploy > New Deployment > Web App.
 * 7. Set "Execute as: Me" and "Who has access: Anyone".
 * 8. Copy the Web App URL and set it as GOOGLE_SCRIPT_URL in your environment.
 */

// Trigger function to detect new rows and send welcome email
function onPartnerRowAdded(e) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName("Partners");
  const lastRow = ss.getSheetByName("Partners").getLastRow();
  const range = sheet.getRange(lastRow, 1, 1, 6); // Read new row
  const values = range.getValues()[0];
  
  const [username, password, name, refCode, email, dateJoined] = values;
  
  // Basic validation to ensure it's a new entry and has an email
  // We use column 7 (G) to track if welcome email was sent
  if (email && email.toString().includes("@") && !sheet.getRange(lastRow, 7).getValue()) {
    sendWelcomeEmail(name, email, refCode);
    sheet.getRange(lastRow, 7).setValue("Welcome Email Sent"); 
  }
}

function sendWelcomeEmail(name, email, refCode) {
  const referralLink = "https://enchiridion.ng/?ref=" + refCode;
  const subject = "Welcome to the Enchiridion Partner Program, " + name + "! 📚";
  
  const body = "Hello " + name + ",\n\n" +
    "Welcome to the Enchiridion family! We are excited to have you as a partner in making Concise Medical Knowledge accessible to everyone.\n\n" +
    "Here is a quick guide to your account:\n\n" +
    "Dashboard Login: Access your 'Rewards' tab on our website to see your points.\n\n" +
    "Your Referral Link: " + referralLink + "\n\n" +
    "The Goal: Remember, every book purchase via your link earns you 5 points (₦500), while simple browsing earns you 0.1 points (₦10).\n\n" +
    "Copy & Paste or Click & Share: Use your dashboard to share directly to WhatsApp and start earning today!\n\n" +
    "Best regards,\n" +
    "The Enchiridion Team";

  try {
    MailApp.sendEmail({
      to: email,
      subject: subject,
      body: body
    });
    Logger.log("Welcome email sent to: " + email);
  } catch (error) {
    Logger.log("Error sending email: " + error.toString());
  }
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action;
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    if (action === "login") {
      return handleLogin(data, ss);
    } else if (action === "register") {
      return handleRegister(data, ss);
    } else if (action === "logActivity") {
      return handleLogActivity(data, ss);
    } else if (action === "updatePayout") {
      return handleUpdatePayout(data, ss);
    }
    
    return ContentService.createTextOutput(JSON.stringify({ success: false, error: "Invalid action" }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ success: false, error: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function handleLogin(data, ss) {
  const sheet = ss.getSheetByName("Partners");
  const rows = sheet.getDataRange().getValues();
  const { username, password } = data;
  
  // Headers: Name, Email (Username), Password, ReferralCode, ...
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][1] === username && rows[i][2] === password) {
      return ContentService.createTextOutput(JSON.stringify({ 
        success: true, 
        partner: {
          name: rows[i][0],
          refCode: rows[i][3]
        }
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }
  
  return ContentService.createTextOutput(JSON.stringify({ success: false, error: "Invalid credentials" }))
    .setMimeType(ContentService.MimeType.JSON);
}

function handleLogActivity(data, ss) {
  const sheet = ss.getSheetByName("ActivityLog");
  const { type, refCode, points, timestamp, details } = data;
  
  // Headers: Timestamp, ReferralCode, ActivityType, Points, URL
  sheet.appendRow([timestamp, refCode, type, points, details.url]);
  
  return ContentService.createTextOutput(JSON.stringify({ success: true }))
    .setMimeType(ContentService.MimeType.JSON);
}

function handleUpdatePayout(data, ss) {
  const sheet = ss.getSheetByName("PayoutSettings");
  const { refCode, accountName, accountNumber, bankName } = data;
  const rows = sheet.getDataRange().getValues();
  
  // Headers: ReferralCode, AccountName, AccountNumber, BankName
  let found = false;
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][0] === refCode) {
      sheet.getRange(i + 1, 1, 1, 4).setValues([[refCode, accountName, accountNumber, bankName]]);
      found = true;
      break;
    }
  }
  
  if (!found) {
    sheet.appendRow([refCode, accountName, accountNumber, bankName]);
  }
  
  return ContentService.createTextOutput(JSON.stringify({ success: true }))
    .setMimeType(ContentService.MimeType.JSON);
}

function handleRegister(data, ss) {
  const sheet = ss.getSheetByName("Partners");
  const rows = sheet.getDataRange().getValues();
  const { email, password, name, refCode, refLink } = data;
  
  // Check if email already exists
  for (let i = 1; i < rows.length; i++) {
    if (rows[i][1] === email) {
      return ContentService.createTextOutput(JSON.stringify({ 
        success: false, 
        error: "Account with this email already exists." 
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }
  
  // Headers: Full Name, Email (Username), Password, Referral Code, Referral Link, Points, Revenue (₦), DateJoined
  sheet.appendRow([name, email, password, refCode, refLink, 0, 0, new Date()]);
  
  return ContentService.createTextOutput(JSON.stringify({ success: true }))
    .setMimeType(ContentService.MimeType.JSON);
}
