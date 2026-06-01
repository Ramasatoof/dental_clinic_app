const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

function getEnv(name, fallback = "") {
  return (process.env[name] || fallback).toString().trim();
}

function createTransporter() {
  const gmailEmail = getEnv("GMAIL_EMAIL");
  const gmailAppPassword = getEnv("GMAIL_APP_PASSWORD");

  if (!gmailEmail || !gmailAppPassword) {
    throw new Error(
      "Missing GMAIL_EMAIL or GMAIL_APP_PASSWORD in functions/.env"
    );
  }

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailEmail,
      pass: gmailAppPassword,
    },
  });
}

function getTimeZone() {
  return getEnv("TIME_ZONE", "Asia/Amman");
}

function formatDateTime(value, language = "ar") {
  const date =
    value && typeof value.toDate === "function" ? value.toDate() : new Date(value);

  const locale = language === "en" ? "en-US" : "ar-JO";

  return new Intl.DateTimeFormat(locale, {
    timeZone: getTimeZone(),
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function buildReminderEmail(data) {
  const language = (data.language || "ar").toString().toLowerCase() === "en"
    ? "en"
    : "ar";

  const clinicName = getEnv("CLINIC_NAME", "Dental Clinic");
  const clinicPhone = getEnv("CLINIC_PHONE", "");
  const patientName = (data.patient_name || "").toString().trim();
  const doctorName = (data.doctor_name || "").toString().trim();
  const formattedDateTime = formatDateTime(data.appointment_datetime || data.date, language);

  if (language === "en") {
    const subject = `Reminder: your upcoming appointment at ${clinicName}`;
    const html = `
      <div style="font-family: Arial, sans-serif; line-height:1.8; color:#222;">
        <h2 style="color:#26619C;">Upcoming Appointment Reminder</h2>
        <p>Hello ${patientName || "Patient"},</p>
        <p>This is a reminder for your upcoming appointment at <strong>${clinicName}</strong>.</p>
        <p><strong>Date & Time:</strong> ${formattedDateTime}</p>
        <p><strong>Doctor:</strong> ${doctorName || "-"}</p>
        ${clinicPhone ? `<p><strong>Clinic Phone:</strong> ${clinicPhone}</p>` : ""}
        <p>Please arrive a few minutes early.</p>
        <p>Thank you.</p>
      </div>
    `;

    return { subject, html };
  }

  const subject = `تذكير بموعدك القادم في ${clinicName}`;
  const html = `
    <div dir="rtl" style="font-family: Arial, sans-serif; line-height:1.9; color:#222; text-align:right;">
      <h2 style="color:#26619C;">تذكير بموعدك القادم</h2>
      <p>مرحبًا ${patientName || "مريضنا الكريم"}،</p>
      <p>هذا تذكير بموعدك القادم في <strong>${clinicName}</strong>.</p>
      <p><strong>التاريخ والوقت:</strong> ${formattedDateTime}</p>
      <p><strong>الطبيب:</strong> ${doctorName || "-"}</p>
      ${clinicPhone ? `<p><strong>هاتف العيادة:</strong> ${clinicPhone}</p>` : ""}
      <p>يرجى الحضور قبل الموعد بعدة دقائق.</p>
      <p>مع تمنياتنا لك بالسلامة.</p>
    </div>
  `;

  return { subject, html };
}

async function updatePatientReminderStatus({
  patientId,
  status,
  errorMessage = null,
  appointmentDateTime = null,
}) {
  if (!patientId) return;

  const payload = {
    last_reminder_status: status,
    last_reminder_error: errorMessage,
    last_reminder_sent_at:
      status === "sent" ? admin.firestore.Timestamp.now() : null,
    reminder_sent_for_session: appointmentDateTime || null,
  };

  await db.collection("patients").doc(patientId).update(payload);
}

async function markAppointmentAsFailed(docRef, data, reason) {
  await docRef.update({
    reminder_status: "failed",
    reminder_error: reason,
    reminder_sent_at: null,
    updated_at: admin.firestore.Timestamp.now(),
  });

  await updatePatientReminderStatus({
    patientId: data.patient_id,
    status: "failed",
    errorMessage: reason,
    appointmentDateTime: data.appointment_datetime || null,
  });
}

async function markAppointmentAsSent(docRef, data) {
  const now = admin.firestore.Timestamp.now();

  await docRef.update({
    reminder_status: "sent",
    reminder_error: null,
    reminder_sent_at: now,
    updated_at: now,
  });

  await updatePatientReminderStatus({
    patientId: data.patient_id,
    status: "sent",
    errorMessage: null,
    appointmentDateTime: data.appointment_datetime || null,
  });
}

exports.sendDueAppointmentReminders = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: getTimeZone(),
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collection("appointments")
      .where("reminder_status", "==", "pending")
      .limit(100)
      .get();

    if (snapshot.empty) {
      logger.info("No pending reminders found.");
      return;
    }

    const transporter = createTransporter();

    let sentCount = 0;
    let skippedCount = 0;
    let failedCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();

      try {
        const reminderEnabled = data.reminder_enabled === true;
        const email = (data.patient_email || "").toString().trim();
        const scheduledFor = data.reminder_scheduled_for;

        if (!reminderEnabled) {
          skippedCount++;
          continue;
        }

        if (!scheduledFor || typeof scheduledFor.toMillis !== "function") {
          failedCount++;
          await markAppointmentAsFailed(doc.ref, data, "Missing reminder_scheduled_for");
          continue;
        }

        if (scheduledFor.toMillis() > now.toMillis()) {
          skippedCount++;
          continue;
        }

        if (!email) {
          failedCount++;
          await markAppointmentAsFailed(doc.ref, data, "Missing patient_email");
          continue;
        }

        const message = buildReminderEmail(data);

        await transporter.sendMail({
          from: `"${getEnv("CLINIC_NAME", "Dental Clinic")}" <${getEnv("GMAIL_EMAIL")}>`,
          to: email,
          subject: message.subject,
          html: message.html,
        });

        await markAppointmentAsSent(doc.ref, data);
        sentCount++;
      } catch (error) {
        failedCount++;
        const message =
          error && error.message ? error.message.toString() : "Unknown send error";

        logger.error("Failed to send reminder", {
          appointmentId: doc.id,
          error: message,
        });

        await markAppointmentAsFailed(doc.ref, data, message);
      }
    }

    logger.info("Reminder scheduler finished", {
      sentCount,
      skippedCount,
      failedCount,
    });
  }
);

exports.reminderHealthCheck = onRequest((req, res) => {
  res.status(200).json({
    ok: true,
    hasGmailEmail: !!getEnv("GMAIL_EMAIL"),
    hasGmailAppPassword: !!getEnv("GMAIL_APP_PASSWORD"),
    timeZone: getTimeZone(),
    timestamp: new Date().toISOString(),
  });
});