from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader
out='output/pdf/E-Health_App_Progress_Report.pdf'
teal=colors.HexColor('#005747'); mint=colors.HexColor('#edf8f2'); ink=colors.HexColor('#182b30')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='TitleCustom',fontName='Helvetica-Bold',fontSize=24,leading=29,textColor=teal,spaceAfter=8))
styles.add(ParagraphStyle(name='SubCustom',fontSize=10,leading=15,textColor=colors.HexColor('#64777c'),spaceAfter=17))
styles.add(ParagraphStyle(name='SectionCustom',fontName='Helvetica-Bold',fontSize=14,leading=19,textColor=teal,spaceBefore=14,spaceAfter=10))
styles.add(ParagraphStyle(name='BodyCustom',fontSize=10,leading=15,textColor=ink,spaceAfter=7))
styles.add(ParagraphStyle(name='CellCustom',fontSize=9,leading=13,textColor=ink))
styles.add(ParagraphStyle(name='LabelCustom',fontName='Helvetica-Bold',fontSize=9,leading=13,textColor=teal))
def p(t,style='BodyCustom'): return Paragraph(t,styles[style])
def footer(c,d):
    w,h=A4
    c.setStrokeColor(colors.HexColor('#dbe9e3'));c.line(40,42,w-40,42)
    c.setFont('Helvetica',8);c.setFillColor(colors.HexColor('#64777c'))
    c.drawString(40,29,'E-Health | Development Progress | 07 October 2026')
    c.drawRightString(w-40,29,f'{d.page}')
rows=[
('Home Dashboard','Redesigned header, E Sync device card, six health metric cards, goals and insights. Preserved existing data sources and unavailable-data states.'),
('Navigation','Updated shared bottom navigation, icons, active-tab styling and SafeArea spacing. Preserved routes and tab behavior.'),
('Bluetooth &amp; Device Setup','Redesigned connection screen; separated permissions from adapter power; added Android enable-prompt handling, scan controls, device-name fallbacks and connection/error states.'),
('Authentication','Preserved Supabase email/password login, registration and SDK session restoration. Added registration OTP verification and resend handling.'),
('Password Recovery','Implemented recovery verification, new-password validation and confirmed success navigation. Prevented premature Dashboard redirects.'),
('Email Delivery','Implemented a signed server-side Brevo hook with separate registration and recovery OTP emails. Credentials remain outside Flutter.'),
('Profile Management','Implemented real profile updates, photo selection/preview, upload/replacement/removal handling, validation and shared profile refresh.'),
('Supabase Storage','Added version-controlled avatar bucket configuration and user-isolation policies.'),
('Onboarding','Moved onboarding after authentication for incomplete accounts; removed View Onboarding from Profile.'),
('Branding &amp; UI','Added the existing logo to relevant screens, centered authentication logos and removed unnecessary AppBars. Preserved images, colors and animations.'),
('Responsive Layouts','Checked small/large screens, enlarged text, keyboard scrolling and reduced-motion behavior.')]
story=[p('E-Health App','TitleCustom'),p('Overall Progress Report | 07 October 2026','SubCustom'),p('Implementation Overview','SectionCustom')]
data=[[p('Module','LabelCustom'),p('Work completed','LabelCustom')]]+[[p(a,'LabelCustom'),p(b,'CellCustom')]for a,b in rows]
t=Table(data,colWidths=[132,383],repeatRows=1,hAlign='LEFT')
t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),mint),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),10),('RIGHTPADDING',(0,0),(-1,-1),10),('TOPPADDING',(0,0),(-1,-1),9),('BOTTOMPADDING',(0,0),(-1,-1),9),('LINEBELOW',(0,0),(-1,-1),.4,colors.HexColor('#dbe9e3'))]))
story += [t,PageBreak(),p('Validation &amp; Release Readiness','TitleCustom'),p('Completed checks and remaining external dependencies','SubCustom'),p('Testing and Builds','SectionCustom')]
for text in ['Full Flutter regression suite: <b>128 tests passed</b>.','Latest authentication layout changes: <b>18 checks passed</b>.','Email-hook suite: <b>9 tests passed</b>.','Flutter analyzer: <b>no issues</b>.','Android APK and iOS simulator builds succeeded during development.']:
    story.append(p(text))
story += [p('Outstanding Work','SectionCustom')]
for text in ['Supplied Brevo credentials returned <b>401 Unauthorized</b>; live delivery remains blocked.','Hosted Supabase email hook/templates, secrets and avatar migrations still need deployment/configuration.','Real email delivery, hosted OTP expiration/rate limits, persistent photo uploads and two-user storage isolation remain unverified.','Native Bluetooth dialogs and physical wearable behavior require device testing.','Wearable health synchronization still requires the verified device protocol; missing readings are not replaced with fabricated data.']:
    story.append(p('- '+text))
story += [Spacer(1,12),p('Release Status','SectionCustom'),p('Implementation and automated checks are complete for the changes described. Production readiness depends on backend configuration and live email, storage and device verification.'),Spacer(1,14),p('Verification note: automated/mock checks do not establish successful production email delivery, storage isolation or physical-device behavior.','SubCustom')]
SimpleDocTemplate(out,pagesize=A4,rightMargin=40,leftMargin=40,topMargin=38,bottomMargin=58,title='E-Health App - Overall Progress Report',author='E-Health Development').build(story,onFirstPage=footer,onLaterPages=footer)
r=PdfReader(out);print('Pages:',len(r.pages));assert len(r.pages)==2
assert 'Outstanding Work' in r.pages[1].extract_text()
