# Tools

Provide your agent with real time information and the ability to take action in third party apps with external function calls.

Tools allow you to make external function calls to third party apps so you can get real-time information. You might use tools to:

Calendar Management

Schedule appointments and manage availability on someone’s calendar

Restaurant Bookings

Book restaurant reservations and manage dining arrangements

CRM Integration

Create or update customer records in a CRM system

Inventory Lookup

Get inventory data to make product recommendations

To help you get started with Tools, we’ll walk through an “AI receptionist” we created by integrating with the Cal.com API.

## Tools Overview

### Secrets

Before we proceed with creating our Tools, we will first create a Secret to securely store our API keys. The Cal.com API we will use for our example takes a Bearer token so we will first add a Secret named “Bearer” and provide the Bearer token as the value.

You can find Secrets within the Conversational AI Dashboard in the Agent subnav.

### Webhooks

Next, look for “Tools” in the “Agent” subnav. Add a new Tool to configure your webhook. For our AI receptionist, we created two Tools to interact with the Cal.com API:

###### Get Available Slots

###### Book Meeting

### Headers

Within the Cal.com documentation, we see that both our availability and booking endpoints require the same three headers:

`   $  Content-Type: application/json  >  cal-api-version: 2024-08-13  >  Authorization: Bearer <your-bearer-token>           `

We configured that as follows:

Type

Name

Value

Value

Content-Type

application/json

Value

cal-api-version

2024-08-13

Secret

Bearer

Bearer (the secret key we defined earlier)

### Path Parameters

You can add path parameters by including variables surrounded by curly brackets in your URL like this {variable}. Once added to the URL path, it will appear under Path Parameters with the ability to update the Data Type and Description. Our AI receptionist does not call for Path Parameters so we will not be defining any.

### Query Parameters

Get and Delete requests typically have query parameters while Post and Patch do not. Our Get\_Available\_Slots tool relies on a Get request that requires the following query parameters: startTime, endTime, eventTypeId, eventTypeSlug, and duration.

In our Description for each, we define a prompt that our Conversational Agent will use to extract the relevant information from the call transcript using an LLM.

Here’s how we defined our query parameters for our AI receptionist:

Identifier

Data Type

Required

Description

startTime

String

Yes

The start time of the slot the person is checking availability for in UTC timezone, formatted as ISO 8601 (e.g., ‘2024-08-13T09:00:00Z’). Extract time from natural language and convert to UTC.

endTime

String

Yes

The end time of the slot the person is checking availability for in UTC timezone, formatted as ISO 8601 (e.g., ‘2024-08-13T09:00:00Z’). Extract time from natural language and convert to UTC.

eventTypeSlug

String

Yes

The desired meeting length. Should be 15minutes, 30minutes, or 60minutes.

eventTypeId

Number

Yes

The desired meeting length, as an event id. If 15 minutes, return 1351800. If 30 minutes, return 1351801. If 60 minutes, return 1351802.

Event type IDs can differ. Use the [find event types endpoint](https://cal.com/docs/api-reference/v1/event-types/find-all-event-types) to get the IDs of the relevant events.

### Body Parameters

Post and Patch requests typically have body parameters while Get and Delete do not. Our Book\_Meeting tool is a Post request and requires the following Body Parameters: startTime, eventTypeId, attendee.

In our Description for each, we define a prompt that our Conversational Agent will use to extract the relevant information from the call transcript using an LLM.

Here’s how we defined our body parameters for our AI receptionist:

Identifier

Data Type

Required

Description

startTime

String

Yes

The start time of the slot the person is checking availability for in UTC timezone, formatted as ISO 8601 (e.g., ‘2024-08-13T09:00:00Z’). Extract time from natural language and convert to UTC.

eventTypeId

Number

Yes

The unique Cal event ID for the meeting duration. Use 1351800 for a 15-minute meeting, 1351801 for 30 minutes, and 1351802 for 60 minutes. If no specific duration is provided, default to 1351801 (30 minutes).

attendee

Object

Yes

The info on the attendee including their full name, email address and time zone.

Since attendee is an object, it’s subfields are defined as their own parameters:

Identifier

Data Type

Required

Description

name

String

Yes

The full name of the person booking the meeting.

email

String

Yes

The email address of the person booking the meeting. Should be a properly formatted email.

timeZone

String

Yes

The caller’s timezone. Should be in the format of ‘Continent/City’ like ‘Europe/London’ or ‘America/New\_York’.

### Adjusting System Prompt to reference your Tools

Now that you’ve defined your Tools, instruct your agent on when and how to invoke them in your system prompt. If your Tools require the user to provide information, it’s best to ask your agent to collect that information before calling it (though in many cases your agent will be able to realize it is missing information and will request for it anyway).

Here’s the System Prompt we use for our AI Receptionist:

> You are my receptionist and people are calling to book a time with me.
>
> You can check my availability by using Get\_Available\_Slots. That endpoint takes start and end date/time and returns open slots in between. If someone asks for my availability but doesn’t specify a date / time, just check for open slots tomorrow. If someone is checking availability and there are no open slots, keep checking the next day until you find one with availability.
>
> Once you’ve agreed upon a time to meet, you can use Book\_Meeting to book a call. You will need to collect their full name, the time they want to meet, whether they want to meet for 15, 30 or 60 minutes, and their email address to book a meeting.
>
> If you call Book\_Meeting and it fails, it’s likely either that the email address is formatted in an invalid way or the selected time is not one where I am available.

It’s important to note that the choice of LLM matters. We recommend trying out different LLMs and modifying the prompt as needed.
