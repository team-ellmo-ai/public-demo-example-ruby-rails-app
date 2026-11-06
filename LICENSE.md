# eLLMo AI Rails Demo App and Rails SDK License

**Copyright © 2026 eLLMo AI. All rights reserved.**
**Last updated: November 6, 2026**

This is a proprietary software license. It is not an open source license. Read it before
downloading, installing, deploying, or using the Software.

This License is **supplemental to**, and incorporates by reference, the eLLMo AI
[Terms & Conditions](https://www.tryellmo.ai/legal/terms) and
[Acceptable Use Policy](https://www.tryellmo.ai/legal/acceptable-use). Where this License is
silent, those documents govern. Where they conflict, Section 13 sets the order of precedence.

---

## 1. Definitions

Capitalized terms not defined here have the meaning given in the
[Terms & Conditions](https://www.tryellmo.ai/legal/terms).

**"Software"** means all files contained in this repository, including (a) the Ruby on Rails
demo application, its source code, views, styles, scripts, configuration, and documentation, and
(b) the eLLMo AI Rails SDK (`ellmo-ai-rails`) distributed in the `dist/` directory, its source
code, generators, and documentation, together with any updates, modifications, or new versions
provided to you, and any running deployment of any of them.

**"SDK"** means the `ellmo-ai-rails` gem described in (b) above.

**"eLLMo"** means eLLMo AI, the owner of the Software.

**"You"** or **"Subscriber"** means the individual or legal entity holding an active,
paid-in-full Platform Subscription that includes access to the Software.

**"Platform Subscription"** has the meaning given in the Terms & Conditions: your paid plan,
billed in advance on a recurring basis, renewing automatically unless cancelled with 30 days'
notice by email.

**"Tier"** means the named plan or bundle under your Platform Subscription that includes access
to the Software.

**"Authorized Users"** means your employees and individual contractors working on your own
internal business, who have been made aware of and are bound by the terms of this License.
Consistent with the Terms & Conditions, there are no per-seat fees for Authorized Users.

**"Covered Websites"** means the websites covered by your Platform Subscription, for which eLLMo
has issued you a client ID.

**"Deployment"** means any running instance of the Software, including a web application that
includes the SDK, a local server, or a container image run on any infrastructure.

**"Derivative Works"** means any modification, adaptation, translation, extension,
configuration, fork, or work based upon the Software, in whole or in part.

**"Content"** means the structured data, semantic HTML, and other content eLLMo generates for
your Covered Websites and the SDK adds to your pages.

**"Visit Data"** means the information the SDK sends to eLLMo about each page view, as described
in eLLMo's [Rails SDK documentation](https://docs.tryellmo.ai/developers/rails/how-it-works),
including the page URL, request headers, the visitor's IP address, the response status, timing,
and the `ellmo_ext_vid` visitor identifier.

---

## 2. License grant

Subject to your continuous compliance with this License, the Terms & Conditions, and the
Acceptable Use Policy, and to your payment of all fees due, eLLMo grants you a **limited,
non-exclusive, non-transferable, non-sublicensable, revocable license**, for the term of your
active Platform Subscription only, to:

**(a)** download, install, and run the SDK in web applications that serve your Covered Websites,
on infrastructure controlled by you or your hosting providers;

**(b)** download, run, and study the demo application to evaluate and learn how to integrate the
SDK;

**(c)** permit Authorized Users to do the above in the course of your internal business
operations; and

**(d)** create Derivative Works solely for your own internal use, subject to Section 4.

This grant is limited to your Tier. Access to one Tier confers no rights to any other Tier, and
no rights to Software eLLMo has not made available to you.

The fact that eLLMo makes this repository publicly visible does not grant any right to use the
Software. No rights are granted other than those expressly stated above. All rights not expressly
granted are reserved by eLLMo.

---

## 3. Restrictions

The [Acceptable Use Policy](https://www.tryellmo.ai/legal/acceptable-use) applies in full to the
Software, including its restrictions on reverse engineering and competitive use (AUP §6). In
addition, and specific to the Software, you shall not, and shall not permit any third party to:

**(a)** distribute, publish, sell, resell, rent, lease, lend, sublicense, or otherwise make the
Software or any Derivative Work available to any third party, whether for a fee or free of
charge;

**(b)** use the SDK on any website that is not a Covered Website, or operate it as a service for
third parties;

**(c)** host, mirror, publish, or make the Software available through any public or private
repository, marketplace, package registry, container registry accessible to third parties, model
context server, or file-sharing service, other than a private repository you control that holds
the source code of your own Covered Website;

**(d)** remove, alter, obscure, or fail to reproduce any copyright notice, attribution, license
header, or proprietary marking contained in the Software;

**(e)** use the Software, or any portion of it, to develop, train, fine-tune, or evaluate a
product or service that competes with the Software or with eLLMo;

**(f)** use the Software as training data for, or as input to the training of, any machine
learning model. This mirrors eLLMo's own commitment in the
[AI Policy](https://www.tryellmo.ai/legal/ai) not to train models on your data for the benefit of
others;

**(g)** modify the SDK to send eLLMo false, fabricated, or misattributed Visit Data, or to
request Content for websites that are not Covered Websites;

**(h)** exceed the Tier, website, or usage limits set out in your Platform Subscription, or evade
any quota, rate limit, access switch, or paywall control (AUP §5); or

**(i)** use the Software for any purpose prohibited by Section 12.

---

## 4. Derivative Works

You may modify the Software for your own internal use. Any Derivative Work you create:

**(a)** is licensed to you on the same terms and for the same term as the Software itself;

**(b)** may not be distributed, published, or made available to any third party under any
circumstances; and

**(c)** is subject in full to the termination and deletion obligations in Section 6, including
the obligation to delete it.

For the avoidance of doubt, creating a Derivative Work does not create any independent or
perpetual right to use the underlying Software content it incorporates. **Your rights in a
Derivative Work end when your rights in the Software end.**

---

## 5. Ownership

**Our stuff.** eLLMo retains all right, title, and interest in and to the Software, including all
intellectual property rights in it, and including the caching, injection, and visit-reporting
logic and methodologies embodied in it. This License transfers no ownership. This is consistent
with the Terms & Conditions, under which the eLLMo platform, its algorithms, and its models remain
eLLMo's intellectual property.

**Your stuff.** Your website, its code, and your business data remain yours. eLLMo claims no
rights in your application code by reason of your adding the SDK to it.

**Content.** Your rights to use Content are set out in the Terms & Conditions. Consistent with
them, you should review AI-generated Content before relying on it. Content stops being added to
your pages when this License ends.

**Feedback.** If you provide eLLMo with suggestions, feedback, bug reports, or ideas concerning
the Software, you grant eLLMo a perpetual, irrevocable, worldwide, royalty-free license to use
them without restriction or obligation to you.

---

## 6. Term and termination

**Term.** This License begins when you first receive access to the Software and continues only for
so long as your Platform Subscription remains active and paid in full. Platform Subscriptions
renew automatically unless cancelled with 30 days' notice by email, per the Terms & Conditions.

**Automatic termination.** This License terminates immediately and automatically, without notice,
upon the earliest of:

- expiration, cancellation, non-renewal, or lapse of your Platform Subscription;
- your failure to pay any amount due when due;
- your breach of this License, the Terms & Conditions, or the Acceptable Use Policy; or
- eLLMo's suspension or termination of your account under AUP §9.

**No perpetual or residual rights.** You receive **no perpetual license to any version of the
Software.** Consistent with the Terms & Conditions, you lose access to the service immediately on
termination. Continued use of a previously received version after termination, including keeping
the SDK in a running Deployment, is not permitted and constitutes infringement of eLLMo's
copyright.

**Obligations on termination.** Access ends immediately. Within **thirty (30) days** of
termination you shall:

**(a)** cease all use of the Software and of every Derivative Work;

**(b)** remove the SDK from every Deployment, and delete every Deployment of the demo
application;

**(c)** permanently delete all copies of the Software and of every Derivative Work from all
systems under your control, including local machines, servers, repositories, version control
history, backups, and archives, to the extent technically practicable;

**(d)** cease distributing or making available any Derivative Work, and take reasonable steps to
recall any that has been shared internally; and

**(e)** upon eLLMo's written request, provide written certification signed by an authorized
officer that you have complied with (a) through (d).

Where deletion from immutable backups or version control history is not technically practicable,
you may retain such copies solely for as long as the retention schedule requires, provided they
remain inaccessible for use and are deleted on the normal retention cycle.

**Credits.** Any unused Credits are forfeited on termination and are not refundable or
transferable, per the Terms & Conditions.

**Survival.** Sections 3, 4(b), 5, 6, 7, 8, 9, 10, 12, and 13 survive termination.

---

## 7. Proprietary rights in published source

eLLMo makes the source code of the Software visible in this repository so that Subscribers can
inspect, evaluate, and install it. Being able to read the source code does not make the Software
open source or place it in the public domain, and grants no rights beyond those in Section 2. Any
non-public information you receive from eLLMo about the Software, including API details,
credentials, client IDs, and support communications, is eLLMo's confidential information. You
shall protect it with at least reasonable care and disclose it only to Authorized Users with a
need to know.

---

## 8. Audit and tracing

Copies of the Software may contain unique identifying markers that allow eLLMo to trace a copy to
the Subscriber it was issued to, and the SDK identifies itself and your client ID to eLLMo's
services. You shall not attempt to detect, alter, or remove such markers. This is a permitted
integrity control and is not covered by the responsible disclosure invitation in eLLMo's
[Security](https://www.tryellmo.ai/legal/security) policy.

---

## 9. Disclaimer of warranty

THE SOFTWARE IS PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, TITLE, AND NON-INFRINGEMENT.

The SDK changes the HTML your application serves and sends Visit Data to eLLMo from your servers.
**You are solely responsible for testing the Software in your application before deploying it,
and for reviewing the Content added to your pages.** eLLMo does not warrant that the Software is
compatible with your application, hosting, caching, or other middleware, or that Content will
improve your visibility in any search engine or AI assistant. Consistent with the Terms &
Conditions and the [AI Policy](https://www.tryellmo.ai/legal/ai), eLLMo does not warrant that
Content will be accurate, complete, secure, or fit for any purpose.

---

## 10. Limitation of liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL eLLMo BE LIABLE FOR ANY INDIRECT,
INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF PROFITS,
REVENUE, DATA, TRAFFIC, SEARCH RANKING, OR BUSINESS, OR FOR ANY HOSTING OR INFRASTRUCTURE CHARGES,
ARISING OUT OF OR RELATED TO THE SOFTWARE, HOWEVER CAUSED AND UNDER ANY THEORY OF LIABILITY.

Consistent with the Terms & Conditions, eLLMo's **total aggregate liability** arising out of or
related to the Software shall not exceed the greater of (a) the amounts you paid to eLLMo in the
twelve (12) months preceding the event giving rise to the claim, or (b) one hundred US dollars
($100).

---

## 11. Third-party software and data

The demo application and the SDK depend on open source software, such as Ruby on Rails and Rack,
which is licensed to you under its own terms. eLLMo grants no rights in that software.

Where your use of the Software involves personal data, including Visit Data, eLLMo's
[Privacy Policy](https://www.tryellmo.ai/legal/privacy) and, where applicable,
[Data Processing Agreement](https://www.tryellmo.ai/legal/dpa) govern.

---

## 12. Visitors, cookies, and Visit Data

The SDK sends Visit Data about the visitors to your Covered Websites to eLLMo, and sets a
first-party `ellmo_ext_vid` cookie in their browsers unless you turn it off. You are solely
responsible for:

**(a)** having a lawful basis to collect Visit Data and share it with eLLMo, and honoring
data-subject rights, under every law that applies to you and to your visitors, including the
GDPR, UK GDPR, ePrivacy Directive, PECR, CCPA/CPRA, and PIPEDA;

**(b)** disclosing eLLMo and the `ellmo_ext_vid` cookie in your privacy and cookie notices, and
obtaining any consent the law requires before the cookie is set or Visit Data is sent;

**(c)** configuring the SDK, including its `report_visits` and `visitor_cookie` settings, to match
the choices your visitors make; and

**(d)** not using the Software to collect data about anyone in breach of the Acceptable Use
Policy.

---

## 13. General

**Precedence.** In the event of conflict, the following order applies, highest first: (1) a signed
written agreement between you and eLLMo; (2) the
[Terms & Conditions](https://www.tryellmo.ai/legal/terms); (3) this License; (4) any license file
included in the SDK; (5) the [Acceptable Use Policy](https://www.tryellmo.ai/legal/acceptable-use)
and other posted policies. This License supplements and does not replace the Terms & Conditions.

**Governing law and disputes.** This License is governed by the laws of the State of Delaware,
United States. Disputes will be handled through binding arbitration unless your local laws
provide otherwise, consistent with the Terms & Conditions.

**Assignment.** You may not assign or transfer this License, by operation of law or otherwise,
without eLLMo's prior written consent. eLLMo may assign it freely.

**Equitable relief.** You acknowledge that breach of Sections 3, 4, 6, 7, or 12 would cause eLLMo
irreparable harm for which monetary damages are an inadequate remedy, and that eLLMo is entitled
to seek injunctive relief in addition to any other remedy.

**Severability.** If any provision is held unenforceable, it shall be modified to the minimum
extent necessary to make it enforceable, and the remaining provisions remain in full force.

**No waiver.** eLLMo's failure to enforce any provision is not a waiver of its right to do so
later.

**Changes.** eLLMo may update this License from time to time. Material changes will be
communicated by email or by notice in the service, and take effect at your next billing cycle.
Continued use after the effective date means you accept the updated License.

---

## Contact

**Legal notices, abuse reports, and security:** security@tryellmo.ai
**Licensing, renewals, tier changes, and permission requests:** armando@tryellmo.ai

**eLLMo AI** · [www.tryellmo.ai](https://www.tryellmo.ai) · [Legal](https://www.tryellmo.ai/legal)
