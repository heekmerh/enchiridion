
## Enchiridion — Official Website

---

## 1. Product Summary

**Product Name:** Enchiridion
**Product Type:** Marketing & Information Website
**Platform:** Web (Responsive: Desktop, Tablet, Mobile)
**Phase:** MVP (Future-ready)

**Purpose:**
To serve as the official digital hub for the *Enchiridion* medical books and companion mobile application—presenting both as a cohesive, premium, editorial medical ecosystem.

---

## 2. Product Vision

Enchiridion is positioned as a **modern, authoritative medical reference system** combining:

* Curated specialty-based medical books
* A companion mobile app for on-the-go clinical reference

The website should communicate **credibility, clarity, and premium editorial quality**, while remaining tech-forward and scalable.

---

## 3. Target Audience

* Medical students
* House officers / interns
* Resident doctors
* Practicing clinicians
* Allied health professionals

---

## 4. Design Direction (High-Level)

### 4.1 Visual Style

* **Modern**
* **Tech-forward**
* **Premium**
* **Editorial medical**

Avoid:

* Overly playful UI
* Startup-style bright colors
* Heavy animations

---

### 4.2 Color System (Guidance)

* Editorial medical palette:

  * Off-white / warm neutral backgrounds
  * Charcoal / deep slate primary text
  * Muted medical accent color (e.g. desaturated blue/teal/green)
* High contrast for readability
* Accessible color ratios (WCAG 2.1)

---

### 4.3 Typography

**Hybrid typography system**

* Serif font:

  * Section headers
  * Editorial emphasis
  * Book-adjacent elements
* Sans-serif font:

  * Body text
  * UI elements
  * App feature descriptions

---

## 5. Information Architecture

### Homepage Sections (Top → Bottom)

1. Header / Logo
2. Book Carousel
3. App Information Section
4. App Download Section
5. Reviews & Testimonials
6. Referral Section
7. Footer

Navigation uses **anchor links only** (scroll-to sections).

---

## 6. Functional Requirements (By Section)

---

### 6.1 Header / Logo Section

**Layout**

* Enchiridion logo centered horizontally
* Positioned at the topmost visual layer
* Uses the **interior logo** as the brand mark

**Behavior**

* Shrinks on scroll
* Remains visible during scrolling
* Clicking logo scrolls back to top

**Navigation**

* Minimal anchor links:

  * Books
  * App
  * Reviews
  * Refer

---

### 6.2 Book Carousel Section

**Purpose**

* Showcase Enchiridion specialty books
* Communicate availability status clearly

**Carousel Behavior**

* Manual interaction only
* No auto-scroll
* Swipe enabled on mobile
* Arrow navigation on desktop

**Each Book Card Displays**

* Book cover image
* Book title
* Short description
* Status badge:

  * **Available**
  * **Coming Soon**

**Specialty Rules**

* Pediatrics → Available
* Other specialties → Coming Soon

**On Click**

* Navigates to a **dedicated book page**

---

### 6.3 Book Detail Pages (Per Specialty)

**Structure**

* Separate page per book
* Drop-down / accordion sections

**Content Sections**

* Book overview
* Availability status
* Pricing
* Format (print / digital / app-based)
* Future updates (optional)

**Future-Ready**

* Easy to add new specialties
* Content driven via configuration or CMS-like structure

---

### 6.4 Enchiridion App Section

**Layout**

* Horizontal rectangular container
* Split ratio:

  * 25%: App logo
  * 75%: App details

**Primary Message**

> “A digital companion to the Enchiridion books.”

**Content**

* Detailed description
* Feature list using **icon + text**
* No app screenshots at this stage

**Design Notes**

* Clean editorial layout
* Icons should be minimal and consistent

---

### 6.5 App Download Section

**Position**

* Immediately below App Information section

**Visibility**

* Appears once user scrolls to this section
* Always visible within section

**Elements**

* “Download Now” text
* App Store badge
* Google Play badge

**Platform Detection**

* iOS users → App Store first
* Android users → Play Store first

**Behavior**

* Opens store links in new tab

---

### 6.6 Reviews & Testimonials Section

**Format**

* Carousel / slider
* Manual navigation + optional slow auto-advance

**Review Sources**

* Anyone with access to:

  * Enchiridion app
  * Enchiridion books

**Content Length**

* Medium to long testimonials
* Short quotes also allowed

**Displayed Fields**

* Reviewer name
* Gender icon (male/female)
* Review text

**Explicitly Excluded**

* No profile photos

**Moderation**

* Future-ready for user submissions
* All reviews must be pre-approved before display

---

### 6.7 Referral Section

**Layout**

* Two-column layout (50/50)

#### Column 1: Referral Codes

* Explanation of referral system
* Automatically generated referral codes
* CTA (e.g. “Get Your Code”)

#### Column 2: Refer a Friend

* Step-by-step explanation
* Benefits:

  * App access benefits
  * Discounts
  * Other incentives (to be expanded later)
* CTA (e.g. “Refer Now”)

**Design Reference**

* Layout and flow to follow external reference link (to be provided)

---

## 7. Footer & Trust Elements

**Footer Content**

* Editor’s name
* App developers
* Contributors
* Institutional affiliations (when available)

**Contact Options**

* Contact form
* Email address
* Social media links

**Purpose**

* Establish credibility
* Reinforce academic and professional trust

---

## 8. Technical Requirements

### Frontend

* Modern framework (e.g. React / Next.js)
* Fully responsive
* SEO-friendly structure
* Smooth scrolling for anchor links

### Content Structure

* Easy to add:

  * New books
  * New specialties
  * New reviews
* Static site acceptable for MVP

### Performance

* Optimized images
* Lazy loading for carousels
* Fast load times

---

## 9. Accessibility Requirements

* WCAG 2.1 compliance
* Keyboard-navigable carousels
* Alt text for images
* Proper heading hierarchy

---

## 10. Out of Scope (MVP)

* User authentication
* In-site purchases
* Referral reward logic backend
* Blog or news section

---

## 11. Open Placeholders

* Referral system reference link
* Final app store URLs
* Institutional affiliations
* Expanded referral benefits

---

## 12. Acceptance Criteria

* Layout matches defined structure
* No auto-scrolling book carousel
* Correct “Available” vs “Coming Soon” states
* Platform detection works for app downloads
* Reviews are moderated
* New specialties can be added without redesign

---


