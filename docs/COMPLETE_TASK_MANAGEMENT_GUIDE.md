# 📘 Complete Task Management Guide (Flutter App)

This guide explains the full productivity workflow supported by the app, including task lifecycle management, calendar planning, dashboard insights, and hourly focus tracking.

## 🚀 Overview

The app helps you manage productivity through:

- ✅ Task tracking
- 📅 Calendar scheduling
- 📊 Dashboard insights
- ⏱ Hourly tracking (Urgent vs Important)
- 📆 Daily and weekly planning

---

## 1) 📝 Adding a Task

When creating a task, fill in the following fields.

### 📌 Task details

- **Task Name**: What needs to be done
- **Description (Optional)**: Additional context

### 📅 Scheduling

- **Due Date** (used for):
  - Calendar placement
  - Dashboard tracking
  - Overdue detection

### ⚡ Priority levels

- Low
- Medium
- High
- Very High
- Urgent (Now)

### 📊 Status options

- Not Started
- In Progress
- Completed
- Cancelled
- Overdue

### 🗂 Category examples

- Work
- Personal
- Study
- Health
- Finance

### 👤 Delegate (Optional)

Assign a task to a person (example: Amit, Monika, Ankit).

### ✅ Completion rule

Mark the completion checkbox when done.

> Note: Status text alone is not considered final completion.

---

## 2) ⏱ Hourly Productivity Tracking (Core System)

This is the primary behavior analysis system.

### 📌 How it works

Track your day for **7–10 days**:

Each hour, log:

- Main task performed
- **Urgent?** → Yes / No
- **Important?** → Yes / No

### 🎯 Goal

Measure where your time is actually spent.

### 📊 Automatic matrix (Dashboard)

Entries are grouped into a 2×2 matrix:

|                | Important ❌ | Important ✅ |
|----------------|-------------:|-------------:|
| **Urgent ✅**  | %            | %            |
| **Urgent ❌**  | %            | %            |

### 🧠 Insight use-cases

This identifies:

- Time waste
- Productive work
- High-impact activities

### 💡 Quick examples

- YouTube → Not Urgent, Not Important
- Study → Not Urgent, Important
- Deadline work → Urgent, Important

---

## 3) 😊 Daily Reflection

At the end of each day:

- Ask: **“Did I feel happy/productive today?”**
- Select: **Yes / No**
- Add optional note: why you feel this way

Example notes:

- “Wasted time on YouTube”
- “Completed important tasks”

### 🧠 System-generated outputs

- Advice
- Time-waste summary
- Improvement suggestions

---

## 4) 📅 Calendar View

Tasks appear by their due date automatically.

### ✔ Features

- Monthly calendar navigation
- Current day highlight
- Up to 6 tasks visible per day

### 🔍 Filters

Hide entries with status:

- Completed
- Cancelled
- Skipped

### ➕ Other entries

Also track:

- Events
- Meetings
- Reminders

---

## 5) 📊 Dashboard (Main Control Panel)

### 📈 Summary cards

- Total tasks
- Today’s tasks
- Completed tasks
- Overdue tasks

### ⚡ Priority view

Tasks grouped by priority/importance.

### 📌 Status view

Progress by status.

### 👤 Delegation view

Tasks grouped by assignee.

### ⏰ Overdue view

Overdue tasks sorted by urgency.

### 📆 Today / Tomorrow switch

Quick context switching between immediate plans.

### 🧠 Productivity matrix

Built from hourly tracking to show time distribution.

### 📉 Distribution indicators

- % Urgent
- % Important

---

## 6) 📆 Daily Tasks (New Feature)

Use **Today Tasks** for short-term focus.

Examples:

- Finish API
- Revise Pandas
- Practice SQL

Track each item as:

- Done
- Pending

These tasks appear on the dashboard and improve daily execution focus.

---

## 7) 🗂 Weekly Planning (New Feature)

Plan major weekly outcomes in advance.

### Add weekly goals/deliverables

Examples:

- Complete project module
- Finish interview prep
- Workout 5 days

### 🔄 Progress states

- Completed
- In Progress
- Pending

### 📊 Weekly insights

- Completion rate
- Productivity score
- Improvement suggestions
