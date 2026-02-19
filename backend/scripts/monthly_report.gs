/**
 * Enchiridion Monthly Referral Report Script
 * 
 * Instructions:
 * 1. Open your Enchiridion Google Sheet.
 * 2. Go to Extensions -> Apps Script.
 * 3. Delete any code in the editor and paste this script.
 * 4. Click the 'Save' icon and name it 'MonthlyReport'.
 * 5. To set the trigger:
 *    - Click the Clock icon (Triggers) on the left sidebar.
 *    - Click '+ Add Trigger'.
 *    - Choose 'generateMonthlyReport' as the function to run.
 *    - Select 'Time-driven' as the event source.
 *    - Select 'Month timer' and set it to 'Last day of the month' at '11 PM to midnight'.
 */

function generateMonthlyReport() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const activitySheet = ss.getSheetByName("ActivityLog");
  const partnersSheet = ss.getSheetByName("Partners");
  
  if (!activitySheet || !partnersSheet) {
    Logger.log("Sheets not found. Ensure 'ActivityLog' and 'Partners' exist.");
    return;
  }

  const now = new Date();
  const currentMonth = now.getMonth();
  const currentYear = now.getFullYear();
  const monthNames = ["January", "February", "March", "April", "May", "June",
                      "July", "August", "September", "October", "November", "December"];
  
  // Stats to aggregate
  let stats = {
    browses: 0,
    registrations: 0,
    sales: 0,
    totalPoints: 0,
    payoutLiability: 0,
    partnerPoints: {} // To track monthly top performer
  };

  // 1. Process Activity Log (Browses and Sales)
  const activityData = activitySheet.getDataRange().getValues();
  // Columns: A:Timestamp, B:RefCode, C:Type, D:Points, E:Details, F:Reported
  for (let i = 1; i < activityData.length; i++) {
    const row = activityData[i];
    const timestamp = new Date(row[0]);
    const refCode = row[1];
    const type = row[2];
    const points = parseFloat(row[3]) || 0;
    const reported = row[5];

    if (!reported && timestamp.getMonth() === currentMonth && timestamp.getFullYear() === currentYear) {
      if (type === "Browsing") {
        stats.browses++;
      } else if (type === "Purchase") {
        stats.sales++;
      } else if (type === "Registration" || type === "Registration (Mock)") {
        stats.registrations++;
      }

      stats.totalPoints += points;
      
      // Track points per partner for the top performer
      if (refCode) {
        stats.partnerPoints[refCode] = (stats.partnerPoints[refCode] || 0) + points;
      }

      // Mark as reported immediately in the sheet
      activitySheet.getRange(i + 1, 6).setValue("Reported");
    }
  }

  // 2. Process Partners Database (New Registrations)
  // Even if we tracked regressions in ActivityLog, we verify against Partners sheet DATE_JOINED (Column J)
  const partnersData = partnersSheet.getDataRange().getValues();
  // Column A: Username, C: Full Name, J: Date Joined
  for (let i = 1; i < partnersData.length; i++) {
    const row = partnersData[i];
    const dateJoined = new Date(row[9]); // Column J is index 9
    
    if (dateJoined && dateJoined.getMonth() === currentMonth && dateJoined.getFullYear() === currentYear) {
      // stats.registrations++ // We already counted them in activity log, but could verify here
    }
  }

  stats.payoutLiability = stats.totalPoints * 100;

  // 3. Find Top Performer
  let topPerformerCode = "N/A";
  let maxPoints = 0;
  for (let code in stats.partnerPoints) {
    if (stats.partnerPoints[code] > maxPoints) {
      maxPoints = stats.partnerPoints[code];
      topPerformerCode = code;
    }
  }

  // Look up top performer's name
  let topPerformerName = topPerformerCode;
  if (topPerformerCode !== "N/A") {
    for (let i = 1; i < partnersData.length; i++) {
      if (partnersData[i][3] === topPerformerCode) { // Referral Code is Column D (index 3)
        topPerformerName = partnersData[i][2] || partnersData[i][0]; // Full Name or Username
        break;
      }
    }
  }

  // 4. Send Email Report
  const recipient = "enchiridion.med@gmail.com";
  const subject = `📊 Enchiridion Monthly Referral Report: ${monthNames[currentMonth]} ${currentYear}`;
  
  const body = `
Enchiridion Referral Program Monthly Summary
Month: ${monthNames[currentMonth]} ${currentYear}
--------------------------------------------------

• Total Unique Browses: ${stats.browses}
• Total New Registrations: ${stats.registrations}
• Total Book Sales: ${stats.sales}

• Total Points Issued: ${stats.totalPoints.toFixed(1)}
• Total Revenue Liability: ₦${stats.payoutLiability.toLocaleString()}

🏆 Top Performer of the Month: 
${topPerformerName} (${maxPoints.toFixed(1)} pts)

--------------------------------------------------
This report was automatically generated. All processed activity has been marked as 'Reported'.
  `;

  MailApp.sendEmail(recipient, subject, body);
  Logger.log("Monthly report sent to " + recipient);
}
