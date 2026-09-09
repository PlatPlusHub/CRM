# Booking And Travel Products Model

Version: 0.1
Status: Draft
Canonical: Yes

---

# Booking Model

A booking is a container for one or more travel service items.

A booking may contain:

- Ticket only
- Hotel only
- Visa only
- Full travel program
- Custom combination of services

---

# Booking Items

Each service inside a booking is a separate booking item.

Each booking item must have:

- Service type
- Supplier
- Status
- Cost
- Selling price
- Currency
- Profit calculation
- Documents
- Operational owner
- Finance state

---

# Group Travel

A booking may support group travel.

Example:

A religious travel program for 90 travelers, including adults, children, and infants, with multiple hotels in multiple cities.

The model must support multiple travelers, multiple hotels, multiple services, and multiple currencies inside one booking.

---

# Multi-Currency

Each booking item may have its own currency.

Example:

- Ticket cost in Egyptian pounds
- Visa cost in Saudi riyals
- Hotel cost in US dollars

Exchange rates may be entered manually by the finance manager according to market rate.

Exchange rate changes must be recorded as events.

---

# Supplier Model

A supplier may be:

- Another travel company
- Airline
- Hotel
- Embassy or visa provider
- Freelancer
- Another department in another branch of the same company
- Another department in the same branch
- General supplier

Internal department-to-department service must be modeled carefully so it can be tracked operationally and financially.

---

# Item Status Independence

Every booking item has an independent lifecycle and status.

The booking has an overall state, but item states must remain separate.

Responsibility for an existing booked service is also independent of creating or editing one. Once any booking-item owner slot is occupied, moving or clearing it requires the dedicated reassignment capability, a fresh reason, a server-derived actor/time stamp, and an immutable event. Reassignment never rewrites prior commission or accounting history.

Example:

One booking may contain a ticket that is issued, a hotel that is pending, and a visa that is under review.

