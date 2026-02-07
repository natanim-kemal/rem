import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval(
  "send-notifications",
  { minutes: 30 },
  internal.notifications.runNotificationCron
);

export default crons;
