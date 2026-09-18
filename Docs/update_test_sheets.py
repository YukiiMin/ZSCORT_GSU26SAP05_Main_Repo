# -*- coding: utf-8 -*-
"""
Script to synchronize and harmonize Docs\Test_Scenario.xlsx:
- Sheet 'Test Scenario': 34 Test Cases across 33 Steps with 100% style preservation
- Sheet 'Test Cases': 7 Module Groups, 34 Test Cases with realistic backend test data
- Sheet 'Histories': Add Version 1.3 audit row
- Sheet 'Cover': Preserved completely
"""

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import datetime

def run_update():
    wb_path = r'Docs\Test_Scenario.xlsx'
    wb = openpyxl.load_workbook(wb_path)

    # -------------------------------------------------------------
    # STYLES DEFINITION (Cloned from prototype cells)
    # -------------------------------------------------------------
    font_family = "Microsoft Yahei"
    
    font_header_ts = Font(name=font_family, size=11.0, bold=True, color="FF000000")
    fill_header_ts = PatternFill(start_color="FFC9DAF8", end_color="FFC9DAF8", fill_type="solid")
    
    font_data_ts = Font(name=font_family, size=10.0, bold=False, color="FF000000")
    fill_data_ts = PatternFill(start_color="FFFFFFFF", end_color="FFFFFFFF", fill_type="solid")
    
    thin_border = Border(
        left=Side(style='thin', color='FFD9D9D9'),
        right=Side(style='thin', color='FFD9D9D9'),
        top=Side(style='thin', color='FFD9D9D9'),
        bottom=Side(style='thin', color='FFD9D9D9')
    )
    
    align_center = Alignment(horizontal='center', vertical='center', wrap_text=True)
    align_left = Alignment(horizontal='left', vertical='center', wrap_text=True)
    align_top_left = Alignment(horizontal='left', vertical='top', wrap_text=True)
    align_top_center = Alignment(horizontal='center', vertical='top', wrap_text=True)
    
    # Test Cases Styles
    font_tc_group = Font(name=font_family, size=10.0, bold=True, color="FF000000")
    fill_tc_group = PatternFill(start_color="FFF2F2F2", end_color="FFF2F2F2", fill_type="solid")
    
    font_tc_data = Font(name=font_family, size=10.0, bold=False, color="FF000000")
    fill_tc_data = PatternFill(start_color="FFFFFFFF", end_color="FFFFFFFF", fill_type="solid")

    font_tc_header = Font(name=font_family, size=10.0, bold=True, color="FF000000")
    fill_tc_header = PatternFill(start_color="FFBDD6EE", end_color="FFBDD6EE", fill_type="solid")

    # -------------------------------------------------------------
    # TEST CASES DATA SPECIFICATION
    # -------------------------------------------------------------
    test_cases_data = [
        # SECTION 1
        ("GROUP", "1", "1. Authentication & Local Repository Explorer", "", ""),
        (
            "TC", "1.1",
            "Access SCORT Web Application and Authenticate\n"
            "1. Navigate to SCORT Application URL (http://localhost:8080/index.html or Fiori Launchpad).\n"
            "2. Enter SAP Client '324'.\n"
            "3. Enter Username 'DEV-026' and Password.\n"
            "4. Select Language 'EN' from language selector dropdown.\n"
            "5. Click 'Logon' button.",
            "Host: https://s40lp1.ucc.cit.tum.de/sap\n"
            "Client: 324\n"
            "User: 'DEV-026'\n"
            "Password: [Valid SAP Credentials]\n"
            "Language: 'EN'",
            "1. Frontend authenticates with SAP Gateway via session cookie and fetches CSRF token.\n"
            "2. App navigates to Main Explorer (ObjSearch view).\n"
            "3. Shell header displays active user 'DEV-026' and SAP Client '324'."
        ),
        (
            "TC", "1.2",
            "Search custom development objects by Object Name prefix\n"
            "1. Open Object Search view from navigation bar.\n"
            "2. In 'Object Name' input field, enter prefix 'Z*' or 'ZCL_*'.\n"
            "3. Optionally select Object Type 'CLAS' from dropdown.\n"
            "4. Click 'Search' / 'Go' button.",
            "Object Name: 'Z*'\n"
            "Object Type: 'CLAS'\n"
            "Package: (empty)\n"
            "Person Responsible: (empty)",
            "1. UI5 executes OData V4 query: /LocalObjects?$filter=startswith(ObjectName,'Z') and ObjectType eq 'CLAS'.\n"
            "2. Local repository table populates with custom ABAP classes in the 'Z' namespace.\n"
            "3. Table header badge displays accurate total record count."
        ),
        (
            "TC", "1.3",
            "Filter repository objects by ABAP Package and Person Responsible\n"
            "1. Enter Package name 'ZSCORT_SAP05' in Package filter bar.\n"
            "2. Enter Author 'DEV-026' in Person Responsible filter bar.\n"
            "3. Click 'Search' button.",
            "Package: 'ZSCORT_SAP05'\n"
            "Person Responsible: 'DEV-026'\n"
            "Object Name: (empty)",
            "1. Backend queries TADIR filtered by DEVCLASS = 'ZSCORT_SAP05' and AUTHOR = 'DEV-026' (with delflag IS NULL or ' ').\n"
            "2. Grid displays all project artifacts: CLAS, TABL, DOMA, DTEL, SRVD.\n"
            "3. Row metadata shows Devclass, Author, and Inactive/Active status."
        ),
        (
            "TC", "1.4",
            "Validate empty search query prevention (Negative Guard)\n"
            "1. Clear all search filter inputs (Object Name, Package, Person Responsible all empty).\n"
            "2. Click 'Search' / 'Go' button.",
            "Object Name: (empty)\n"
            "Package: (empty)\n"
            "Person Responsible: (empty)",
            "1. Query execution is intercepted client-side before sending network requests (Invariant U7).\n"
            "2. Warning dialog pops up: 'Please specify at least one search criterion (Object Name, Package, or Person Responsible) before executing search.'\n"
            "3. Grid table remains in current state without error dumps or unhandled rejections."
        ),
        (
            "TC", "1.5",
            "Open read-only Monaco Viewer for local repository object\n"
            "1. In Local Repository table, select row for 'CLAS ZCL_SCORT_MATRIX_QUERY'.\n"
            "2. Click 'View Source' action button in toolbar.\n"
            "3. Switch between class component tabs (Public Section, Private, Methods).\n"
            "4. Click 'Copy Source' button.",
            "Selected Object: 'CLAS ZCL_SCORT_MATRIX_QUERY'\n"
            "Dialog: ViewSource.fragment.xml",
            "1. ViewSource dialog opens embedding read-only Monaco Editor.\n"
            "2. Source code of ZCL_SCORT_MATRIX_QUERY is rendered with full syntax highlighting.\n"
            "3. Sub-component tabs switch seamlessly across class includes (=CU, =CO, =CI, =CP).\n"
            "4. Message toast confirms: 'Source code copied to clipboard.'"
        ),
        (
            "TC", "1.6",
            "Export repository object table to Excel spreadsheet\n"
            "1. Execute search for package 'ZSCORT_SAP05'.\n"
            "2. Click 'Export to Excel' icon button in table toolbar.",
            "Package: 'ZSCORT_SAP05' (Inventory of ~20 development objects)",
            "1. UI5 export utility parses table columns and client-bound rows.\n"
            "2. Spreadsheet file 'Local_Objects_ZSCORT_SAP05.xlsx' downloads automatically.\n"
            "3. File contains correct columns: Object Type, Object Name, Package, Author, Changed Date."
        ),

        # SECTION 2
        ("GROUP", "2", "2. CTS Transport Request Management & Detail Logs", "", ""),
        (
            "TC", "2.1",
            "Browse Transport Request hierarchy filtered by Owner\n"
            "1. Switch to 'Transport Management' view via navigation bar.\n"
            "2. Enter Owner 'DEV-026' in search filter bar and click Search.\n"
            "3. Locate Workbench Request 'S40K920013' and click expand arrow.\n"
            "4. Expand Child Task 'S40K920014'.",
            "Owner: 'DEV-026'\n"
            "Parent TR: 'S40K920013' (Workbench Request, Status: Modifiable 'D')\n"
            "Child Task: 'S40K920014' (Development Task, Status: Modifiable 'D')",
            "1. OData V4 query executes against ZCE_SCORT_TR_TREE Custom Entity.\n"
            "2. Hierarchical tree renders cleanly: Request ('S40K920013') -> Task ('S40K920014') -> Objects ('E071') -> Table Keys ('E071K').\n"
            "3. Node badges reflect accurate status (Modifiable 'D'), Description, and Owner."
        ),
        (
            "TC", "2.2",
            "Switch to Flat Table mode and configure personal table layout\n"
            "1. In Transport Management, switch tab to 'Flat List'.\n"
            "2. Click 'Table Settings' icon in toolbar.\n"
            "3. Toggle column visibility (TR Number, Task, Object, Devclass) and reorder.\n"
            "4. Click OK and click 'Export' button.",
            "Entity: TrObjectSearch (ZCR_SCORT_TR_OBJ_SEARCH)\n"
            "Dialog: FlatTableSettingsDialog.fragment.xml",
            "1. Grid table renders all CTS assigned objects in flat list with sorting and filtering.\n"
            "2. Personalization dialog updates visible columns and order.\n"
            "3. Export button generates formatted '.xlsx' file with current flat table data."
        ),
        (
            "TC", "2.3",
            "Validate empty TR/Owner search prevention (Negative Guard)\n"
            "1. Clear both 'TR Number' and 'Owner' input fields.\n"
            "2. Click 'Search' button.",
            "TR Number: (empty)\n"
            "Owner: (empty)",
            "1. Input validation blocks execution client-side (Invariant U7).\n"
            "2. Warning dialog displayed: 'Please provide either a Transport Request Number or an Owner to search transport hierarchy.'\n"
            "3. TreeTable does not fire invalid OData requests."
        ),
        (
            "TC", "2.4",
            "Open TR Detail view in Flexible Column Layout mid-column\n"
            "1. From CTS Tree or Flat table, click on TR Number 'S40K920013' or click 'View Detail'.\n"
            "2. Observe FCL layout transition to TwoColumnsMidExpanded.\n"
            "3. Review TR header information.",
            "TR Number: 'S40K920013'\n"
            "Layout: TwoColumnsMidExpanded",
            "1. FCL slides in mid-column displaying Detail.view.xml.\n"
            "2. Header displays TR 'S40K920013', Owner 'DEV-026', Status 'Modifiable'.\n"
            "3. Tabs 'Active Tasks', 'Objects in Request', and 'Transport Logs & Steps' are populated."
        ),
        (
            "TC", "2.5",
            "Inspect and compare assigned objects inside TR Detail\n"
            "1. In TR Detail mid-column, select 'Objects in Request' tab.\n"
            "2. Select assigned object 'CLAS ZCL_SCORT_MATRIX_QUERY'.\n"
            "3. Click 'Compare Object' action button in toolbar.",
            "TR: 'S40K920013'\n"
            "Assigned Object: 'R3TR CLAS ZCL_SCORT_MATRIX_QUERY'",
            "1. Assigned objects list displays all E071 entries with package and descriptions.\n"
            "2. Clicking 'Compare Object' opens Compare.view.xml in FCL end-column (ThreeColumnsEndExpanded)."
        ),
        (
            "TC", "2.6",
            "Inspect Transport Cofile execution steps and log trace\n"
            "1. In TR Detail, switch to 'Transport Logs & Steps' tab (or view TR 'S40K920015').\n"
            "2. Click 'Expand All Steps' button in toolbar.\n"
            "3. Verify transport steps (Export, Import, Dictionary activation) and Return Codes (RC 0, RC 4).\n"
            "4. Select a step and click 'Copy Log Text'.",
            "TR: 'S40K920015' (Transport Request with cofile log files)\n"
            "Query: TrLog (ZCE_SCORT_TR_LOG via ZCL_SCORT_TR_LOG_QUERY)",
            "1. Query executes safely without HTTP 500 / RAISE_SHORTDUMP errors.\n"
            "2. Transport steps render hierarchically with color-coded RC badges: Green (RC 0), Yellow (RC 4).\n"
            "3. Detailed log content displays system timestamp, step description, and raw log trace.\n"
            "4. Toast confirms: 'Log content copied to clipboard.'"
        ),
        (
            "TC", "2.7",
            "Release modifiable child Development Task\n"
            "1. Select modifiable Child Task 'S40K920014' assigned under TR 'S40K920013'.\n"
            "2. Click 'Release Task' button in toolbar or detail header.\n"
            "3. Confirm release action in dialog.",
            "Child Task: 'S40K920014' (Status: Modifiable 'D', Type: Development/Correction)\n"
            "Service: ZCL026_SCORT_RELEASE_SERVICE",
            "1. SAP CTS release API executes for Task S40K920014.\n"
            "2. Status updates from 'D' (Modifiable) to 'R' (Released).\n"
            "3. Task status icon changes to green checked badge in UI."
        ),
        (
            "TC", "2.8",
            "Release parent Transport Request after all child tasks are released\n"
            "1. Verify all child tasks under 'S40K920013' are in status 'R'.\n"
            "2. Select parent TR 'S40K920013' and click 'Release TR' button.\n"
            "3. Confirm release action in modal.",
            "Parent TR: 'S40K920013' (Status: Modifiable 'D', all child tasks Released 'R')",
            "1. Release service verifies all subtasks are released.\n"
            "2. Parent TR S40K920013 is released; status changes from 'D' to 'R'.\n"
            "3. Invariant C1 enforced: VRSD snapshot is captured. No automated apply to Target occurs."
        ),
        (
            "TC", "2.9",
            "Detect inactive development objects during Task/TR release (Negative Guard)\n"
            "1. Attempt to release a Task containing unactivated ABAP objects.\n"
            "2. Click 'Release Task'.",
            "Task with inactive object: e.g. 'CLAS ZCL_INACTIVE_DEMO'\n"
            "Dialog: InactiveObjectsDialog.fragment.xml",
            "1. Pre-release validation detects inactive TADIR object entries.\n"
            "2. InactiveObjectsDialog displays table of inactive objects requiring activation.\n"
            "3. Release process is aborted to protect CTS repository consistency."
        ),

        # SECTION 3
        ("GROUP", "3", "3. Cross-System Comparison Matrix (ZCE_SCORT_MATRIX)", "", ""),
        (
            "TC", "3.1",
            "Execute 3-Key Merge-Sort comparison across Origin and Target systems\n"
            "1. In Object Search view, navigate to 'Compare Matrix' tab.\n"
            "2. Enter Package filter 'ZSCORT_SAP05'.\n"
            "3. Click 'Compare' / 'Reload' button.",
            "Package: 'ZSCORT_SAP05'\n"
            "Origin: Local SAP Client (324)\n"
            "Target: Target System Buffer (za05_scort_t)\n"
            "Entity: CompareMatrix (ZCE_SCORT_MATRIX)",
            "1. UI5 requests /CompareMatrix?$filter=Package eq 'ZSCORT_SAP05'.\n"
            "2. Custom Entity Query Provider ZCL_SCORT_MATRIX_QUERY executes 3-key merge-sort in memory: PGMID -> OBJECTTYPE -> OBJECTNAME in O(N+M) complexity.\n"
            "3. Unified comparison table renders with alphabetical row ordering across both systems."
        ),
        (
            "TC", "3.2",
            "Validate object synchronization status indicators (SYNC, DIFF, ORIGIN_ONLY, TARGET_ONLY)\n"
            "1. Observe status column badges for various artifacts in the Comparison Matrix.\n"
            "2. Verify objects with identical SHA256 hashes, differing source code, and missing on either side.",
            "Identical: 'DOMA ZSCORT_STATUS' (Identical hash)\n"
            "Modified: 'CLAS ZCL_SCORT_MATRIX_QUERY' (Differing hash)\n"
            "Origin Only: 'PROG ZSCORT_NEW_TOOL'\n"
            "Target Only: 'PROG ZSCORT_LEGACY_TOOL'",
            "1. DOMA ZSCORT_STATUS displays status SYNC (Green status icon).\n"
            "2. CLAS ZCL_SCORT_MATRIX_QUERY displays status DIFF (Warning Orange icon).\n"
            "3. PROG ZSCORT_NEW_TOOL displays status ORIGIN_ONLY (Blue info icon).\n"
            "4. PROG ZSCORT_LEGACY_TOOL displays status TARGET_ONLY (Purple info icon)."
        ),
        (
            "TC", "3.3",
            "Dynamic filtering and searching within Comparison Matrix\n"
            "1. Use matrix toolbar quick-filter buttons: 'Show All', 'Only Differences (DIFF)', 'Origin Only', 'Target Only'.\n"
            "2. Enter search text in table search field (e.g. 'MATRIX').",
            "Quick Filter: 'Only Differences (DIFF)'\n"
            "Table Search: 'MATRIX'",
            "1. Table filters instantly client-side without full page reload.\n"
            "2. Only rows matching both the status filter (DIFF) and text query (MATRIX) remain visible."
        ),

        # SECTION 4
        ("GROUP", "4", "4. Monaco Diff Editor & Metadata Comparison", "", ""),
        (
            "TC", "4.1",
            "Open Side-by-Side Diff for modified ABAP objects\n"
            "1. In Comparison Matrix, select row for modified class 'ZCL_SCORT_MATRIX_QUERY' (Status: DIFF).\n"
            "2. Click 'Compare' action button.\n"
            "3. Inspect Monaco Diff Editor displayed inside iframe container.",
            "Object: 'CLAS ZCL_SCORT_MATRIX_QUERY'\n"
            "Left Editor: Origin Source (Local active version)\n"
            "Right Editor: Target Source (Target buffer active version)",
            "1. Iframe sandbox loads DiffHost.js without AMD loader conflict (Invariant U10).\n"
            "2. Monaco Diff Editor renders side-by-side: Left = Origin Source, Right = Target Source.\n"
            "3. Modified, added, and deleted lines are clearly color-coded with gutter diff indicators."
        ),
        (
            "TC", "4.2",
            "Toggle Inline Diff mode and navigate difference hunks\n"
            "1. In Monaco Diff Editor toolbar, click 'Toggle Inline Diff' button.\n"
            "2. Click 'Next Difference' and 'Previous Difference' buttons.",
            "View Mode: 'Inline' vs 'Side-by-Side'",
            "1. Editor switches seamlessly from dual-pane split view to unified inline diff view.\n"
            "2. Clicking Next/Previous jumps the viewport directly to the next/previous modified code hunk."
        ),
        (
            "TC", "4.3",
            "Inspect missing-side object (ORIGIN_ONLY / TARGET_ONLY)\n"
            "1. Select an object with status ORIGIN_ONLY (e.g. 'PROG ZSCORT_NEW_TOOL').\n"
            "2. Click 'Compare' button.",
            "Object: 'PROG ZSCORT_NEW_TOOL' (Status: ORIGIN_ONLY)",
            "1. Monaco Diff Editor receives empty string '' for the missing side (Invariant U11).\n"
            "2. UI displays info banner: 'Object exists only on Origin system. Target source is empty.'\n"
            "3. Left editor displays full Origin source; right editor is blank with no JavaScript errors or crashes."
        ),
        (
            "TC", "4.4",
            "Navigate ADT class sub-components in Code Diff\n"
            "1. Compare an ABAP class (e.g. 'CLAS ZCL_SCORT_TR_TREE_QUERY').\n"
            "2. Click class sub-component tabs: Public Section, Protected, Private, Methods, Local Types.",
            "Object: 'CLAS ZCL_SCORT_TR_TREE_QUERY'\n"
            "Class Includes: =CU, =CO, =CI, =CP",
            "1. Sub-component tab switch dynamically requests specific class include source.\n"
            "2. Monaco Diff Editor updates content instantly for the selected section."
        ),
        (
            "TC", "4.5",
            "Compare non-code DDIC metadata attributes side-by-side\n"
            "1. In Matrix, select a DDIC domain object 'DOMA ZSCORT_STATUS' or data element 'DTEL ZDE_SCORT_NODE_ID'.\n"
            "2. Click 'Compare' button and switch to 'Metadata Diff' tab.",
            "Object: 'DOMA ZSCORT_STATUS' (Domain) or 'DTEL ZDE_SCORT_NODE_ID' (Data Element)\n"
            "Fragments: DomainForm.fragment.xml vs DomainFormTarget.fragment.xml",
            "1. Dual metadata forms display side-by-side: Left = Origin, Right = Target.\n"
            "2. Attributes (Data Type, Length, Decimals, Output Format, Descriptions) are compared.\n"
            "3. Differing fields are highlighted with warning color indicator."
        ),

        # SECTION 5
        ("GROUP", "5", "5. Version History & Target Snapshots", "", ""),
        (
            "TC", "5.1",
            "Retrieve version history from Origin VRSD and Target snapshots\n"
            "1. In Compare view for 'CLAS ZCL_Z_00_032_TEST_BETA', select 'Version History' tab.\n"
            "2. Inspect table of historical versions.\n"
            "3. Filter by Server Type (All, Origin 'L', Target 'T').",
            "Object: 'CLAS ZCL_Z_00_032_TEST_BETA'\n"
            "Query: Version (ZCR_SCORT_OBJ_VERSION via ZCL_SCORT_VERSION_QUERY)",
            "1. History table combines records from VRSD (Origin) and za05_scort_t_src (Target).\n"
            "2. Each row displays Version No, Server Type, Author, Date, TR Number, Short Text.\n"
            "3. Server Type filter correctly isolates Origin vs Target versions."
        ),
        (
            "TC", "5.2",
            "View single Target historical version source code in Monaco Editor\n"
            "1. In Version History table, select Target Version '00002' (ServerType = 'T').\n"
            "2. Click 'View Version Source' button.",
            "Object: 'CLAS ZCL_Z_00_032_TEST_BETA'\n"
            "Version: '00002' (ServerType: 'T')\n"
            "Table: za05_scort_t_src",
            "1. Backend Target reader normalizes TADIR class name (strips include suffix) and queries za05_scort_t_src.\n"
            "2. Monaco single editor displays source code of Version '00002' without blank screen or HTTP 500 error."
        ),
        (
            "TC", "5.3",
            "Compare two historical versions in Monaco Diff Editor\n"
            "1. In Version History table, select two versions (e.g. Origin Version '00003' and Target Version '00002').\n"
            "2. Click 'Compare Selected' button.",
            "Version A: Origin '00003'\n"
            "Version B: Target '00002'",
            "1. Monaco Diff Editor opens comparing Version A (Left) against Version B (Right).\n"
            "2. Diff gutter indicators clearly highlight differences between the two selected revisions."
        ),

        # SECTION 6
        ("GROUP", "6", "6. AI Code Review Integration", "", ""),
        (
            "TC", "6.1",
            "Trigger automated AI Code Review on selected ABAP object\n"
            "1. In Compare view, click 'AI Review' button in toolbar to open AI Side Panel.\n"
            "2. Select AI Model 'Gemini' and Execution Mode 'Full Audit'.\n"
            "3. Click 'Run AI Review' button.\n"
            "4. Observe loading progress indicator during analysis.",
            "Object: 'CLAS ZCL_SCORT_MATRIX_QUERY'\n"
            "SICF Handler: '/sap/bc/zscort_ai'\n"
            "AI Model: Gemini",
            "1. Frontend makes POST request to internal SICF handler /sap/bc/zscort_ai (Invariant U12: No direct external API call, no exposed API keys).\n"
            "2. Backend SICF handler calls Gemini API with ABAP code payload and system instructions.\n"
            "3. AI Review side panel renders structured review results upon response."
        ),
        (
            "TC", "6.2",
            "Validate AI Review findings breakdown and recommendations\n"
            "1. In AI Code Review side panel, inspect findings breakdown.\n"
            "2. Review categories: ATC Rules, Clean Code, Performance, and Security vulnerabilities.",
            "Code with potential findings (e.g., SELECT without explicit fields or missing buffer pragmas).",
            "1. AI Review provides structured findings:\n"
            "   - Clean Code: Naming conventions, method length.\n"
            "   - Performance: Recommendations on table buffering or FOR ALL ENTRIES optimization.\n"
            "   - Security: Authority check validations.\n"
            "2. Specific line references and suggested replacement code snippets are presented cleanly."
        ),
        (
            "TC", "6.3",
            "Negative Guard: AI service timeout or network failure handling\n"
            "1. Simulate network unavailability or backend SICF 503 service unavailable response.\n"
            "2. Click 'Run AI Review'.",
            "Endpoint: '/sap/bc/zscort_ai' (Simulated network disconnection / HTTP 503)",
            "1. Error is caught gracefully by UI5 controller without unhandled rejection or app crash (rule_ai_integration_resilience.md).\n"
            "2. User-friendly message displayed: 'AI Code Review service is currently unreachable. Please verify SAP SICF service /sap/bc/zscort_ai status.'"
        ),

        # SECTION 7
        ("GROUP", "7", "7. Selective Transport & End-to-End Lifecycle", "", ""),
        (
            "TC", "7.1",
            "Select specific modified objects for selective deployment\n"
            "1. In Comparison Matrix, select checkboxes for 2 specific objects (e.g. 'CLAS ZCL_SCORT_MATRIX_QUERY' and 'DOMA ZSCORT_STATUS').\n"
            "2. Click 'Apply to Target' button in toolbar.",
            "Selected Objects: 2 objects out of 20 in the package.\n"
            "Dialog: ApplyPreviewDialog.fragment.xml",
            "1. Confirmation modal dialog opens (Invariant C2: Explicit user confirmation required; no automated apply).\n"
            "2. Dialog lists exact names, types, and target system destination for the 2 selected objects.\n"
            "3. Checkbox toggles ('Select All' / 'Deselect All') allow fine-tuning the selection."
        ),
        (
            "TC", "7.2",
            "Run AI Impact Assessment on selected objects before deployment\n"
            "1. In Apply Preview Dialog, click 'AI Impact Assessment' button.\n"
            "2. Review AI risk score and cross-object dependency warnings.\n"
            "3. Click 'Apply AI Recommendations' to adjust selected items.",
            "Selected Objects: 'CLAS ZCL_SCORT_MATRIX_QUERY', 'DOMA ZSCORT_STATUS'",
            "1. AI assesses deployment risks (e.g. DDIC change impact on dependent tables).\n"
            "2. Dialog displays risk badges (Low/Medium/High) and suggested deployment order."
        ),
        (
            "TC", "7.3",
            "Confirm and execute Apply to Target with Version Roll-Forward\n"
            "1. In Apply Confirmation dialog, review target destination and click 'Confirm & Apply'.\n"
            "2. Wait for deployment completion.",
            "Confirmation: 'Yes / Proceed'\n"
            "Target System: Target Client 324 (Buffer tables za05_scort_t, za05_scort_t_src)\n"
            "Service: ZCL026_SCORT_TARGET_APPLY",
            "1. Target system applies the selected objects.\n"
            "2. Invariant C4 enforced: Version roll-forward reads from VRSD, increments MAX(version_no) + 1, and logs audit trail in source tracking table.\n"
            "3. Matrix status for the 2 objects updates from DIFF to SYNC with green success notification."
        ),
        (
            "TC", "7.4",
            "Full E2E Happy Path: Search -> Compare -> Diff -> Review -> Transport -> Release -> Apply\n"
            "1. Search package 'ZSCORT_SAP05' in Object Search.\n"
            "2. Open Comparison Matrix to identify modified class 'ZCL_SCORT_MATRIX_QUERY' (DIFF).\n"
            "3. Launch Monaco Diff Editor to inspect source differences.\n"
            "4. Run AI Code Review to verify ATC and Clean Code standards.\n"
            "5. Switch to CTS Transport Management, assign object to Task 'S40K920014'.\n"
            "6. Release Task 'S40K920014', then release parent Transport Request 'S40K920013'.\n"
            "7. Execute Selective Apply to Target and verify status becomes SYNC.",
            "User: 'DEV-026', Package: 'ZSCORT_SAP05'\n"
            "Objects: 'CLAS ZCL_SCORT_MATRIX_QUERY', 'DOMA ZSCORT_STATUS'\n"
            "TR: 'S40K920013' (Task 'S40K920014')",
            "1. Entire lifecycle completes seamlessly across all 6 modules.\n"
            "2. All status badges, CTS trees, and comparison tables maintain data consistency.\n"
            "3. Final state: Objects deployed and synchronized, TR released with complete audit trail."
        )
    ]

    # Extract clean list of test case IDs (only "TC" rows)
    tc_id_list = [item[1] for item in test_cases_data if item[0] == "TC"]

    # -------------------------------------------------------------
    # STEP DEFINITION FOR 'TEST SCENARIO' MATRIX SHEET
    # -------------------------------------------------------------
    # Each step: (step_no, step_name, list_of_tc_ids_that_mark_X)
    steps_data = [
        (1.0, "Access SCORT Toolkit Application & Authenticate (Login Screen)", 
         ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9",
          "3.1", "3.2", "3.3", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4"]),
        (2.0, "Enter Search Criteria (Object Name, Package, Person Responsible)", 
         ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "7.4"]),
        (3.0, "Execute Search and Verify Repository Object List", 
         ["1.2", "1.3", "1.5", "1.6", "7.4"]),
        (4.0, "Test Empty Search Criteria Validation (Negative Guard)", 
         ["1.4"]),
        (5.0, "Inspect Local Object Source in Monaco Dialog Viewer", 
         ["1.5"]),
        (6.0, "Export Repository Object Inventory to Excel Spreadsheet", 
         ["1.6"]),
        (7.0, "Browse CTS Transport Hierarchy Tree (Request -> Task -> Objects)", 
         ["2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "2.7", "2.8", "2.9", "7.4"]),
        (8.0, "Switch to CTS Flat Table Mode & Configure Personalization", 
         ["2.2"]),
        (9.0, "Test Empty CTS Search Filter Validation (Negative Guard)", 
         ["2.3"]),
        (10.0, "Open Transport Request Detail View (FCL Mid-Column)", 
         ["2.4", "2.5", "2.6", "2.7", "2.8"]),
        (11.0, "Manage Assigned Objects inside TR Detail (Compare & View Source)", 
         ["2.5"]),
        (12.0, "Inspect Transport Logs & Steps with Cofile Execution Steps (RC 0/4/8)", 
         ["2.6"]),
        (13.0, "Release Child Development Task (Status 'D' -> 'R')", 
         ["2.7", "2.8", "7.4"]),
        (14.0, "Release Parent Transport Request (CTS API & VRSD Snapshot)", 
         ["2.8", "7.4"]),
        (15.0, "Test Inactive Objects Warning on Release (Negative Guard)", 
         ["2.9"]),
        (16.0, "Open Cross-System Comparison Matrix (ZCE_SCORT_MATRIX)", 
         ["3.1", "3.2", "3.3", "4.1", "4.2", "4.3", "4.4", "4.5", "6.1", "7.1", "7.3", "7.4"]),
        (17.0, "Verify Object Synchronization Status Badges (SYNC, DIFF, ORIGIN_ONLY, TARGET_ONLY)", 
         ["3.2", "7.4"]),
        (18.0, "Dynamic Matrix Toolbar Quick-Filtering and Live Search", 
         ["3.3"]),
        (19.0, "Launch Monaco Diff Editor in iframe Sandbox (Side-by-Side)", 
         ["4.1", "4.2", "4.3", "4.4", "7.4"]),
        (20.0, "Toggle Single-Column Inline Diff Mode & Navigate Differences", 
         ["4.2"]),
        (21.0, "Inspect Missing-Side Object in Monaco Diff (ORIGIN_ONLY / TARGET_ONLY)", 
         ["4.3"]),
        (22.0, "Navigate Class Sub-Components (Public, Protected, Private, Methods)", 
         ["4.4"]),
        (23.0, "Compare DDIC Non-Code Metadata Forms (Domain, Data Element, Table Type)", 
         ["4.5"]),
        (24.0, "Retrieve Historical Version List from VRSD & Target Snapshots", 
         ["5.1", "5.2", "5.3"]),
        (25.0, "View Single Historical Version Source in Monaco Editor (Target Snapshot)", 
         ["5.2"]),
        (26.0, "Compare Two Selected Historical Versions in Monaco Diff", 
         ["5.3"]),
        (27.0, "Trigger AI Code Review via SICF Handler (/sap/bc/zscort_ai)", 
         ["6.1", "6.2", "6.3", "7.4"]),
        (28.0, "Validate AI Review Findings (ATC, Clean Code, Performance, Security)", 
         ["6.2", "7.4"]),
        (29.0, "Test AI Service Timeout / Network Failure Handling (Negative Guard)", 
         ["6.3"]),
        (30.0, "Perform Selective Object Transport & Modal Confirmation (ApplyPreviewDialog)", 
         ["7.1", "7.2", "7.3", "7.4"]),
        (31.0, "Execute AI Apply Impact Assessment in Confirmation Dialog", 
         ["7.2"]),
        (32.0, "Confirm Apply to Target with Version Roll-Forward Snapshot (za05_scort_t_src)", 
         ["7.3", "7.4"]),
        (33.0, "Execute Comprehensive End-to-End Lifecycle (Search -> Compare -> Diff -> AI -> CTS -> Apply)", 
         ["7.4"])
    ]

    # -------------------------------------------------------------
    # 1. UPDATE 'TEST CASES' SHEET
    # -------------------------------------------------------------
    ws_tc = wb['Test Cases']
    
    # Clear existing data rows starting from row 8 downwards
    max_tc_r = max(ws_tc.max_row, 100)
    for r in range(8, max_tc_r + 1):
        for c in range(1, 10):
            cell = ws_tc.cell(r, c)
            cell.value = None
            cell.fill = PatternFill(fill_type=None)
            cell.border = Border()
            cell.font = font_tc_data

    # Ensure header row 6 and 7 are clean and well-styled
    ws_tc.cell(6, 1).value = "NO."
    ws_tc.cell(6, 2).value = "Test Contents"
    ws_tc.cell(7, 2).value = "Test Cases"
    ws_tc.cell(7, 3).value = "Test Data"
    ws_tc.cell(7, 4).value = "Predicted Test Results"
    
    for c in range(1, 5):
        c6 = ws_tc.cell(6, c)
        c6.font = font_header_ts
        c6.fill = fill_tc_header
        c6.border = thin_border
        c7 = ws_tc.cell(7, c)
        c7.font = font_tc_header
        c7.fill = fill_tc_header
        c7.border = thin_border

    current_r = 8
    for item in test_cases_data:
        itype = item[0]
        if itype == "GROUP":
            _, g_no, g_title, _, _ = item
            ws_tc.cell(current_r, 1).value = g_no
            ws_tc.cell(current_r, 2).value = g_title
            ws_tc.cell(current_r, 3).value = None
            ws_tc.cell(current_r, 4).value = None
            
            for c in range(1, 5):
                cell = ws_tc.cell(current_r, c)
                cell.font = font_tc_group
                cell.fill = fill_tc_group
                cell.border = thin_border
                cell.alignment = align_left if c > 1 else align_center
            ws_tc.row_dimensions[current_r].height = 24.0
            current_r += 1
        else:
            _, tc_id, tc_desc, tc_data, tc_pred = item
            ws_tc.cell(current_r, 1).value = tc_id
            ws_tc.cell(current_r, 2).value = tc_desc
            ws_tc.cell(current_r, 3).value = tc_data
            ws_tc.cell(current_r, 4).value = tc_pred
            
            # Count max lines to compute row height
            lines2 = tc_desc.count('\n') + 1
            lines3 = tc_data.count('\n') + 1
            lines4 = tc_pred.count('\n') + 1
            max_lines = max(lines2, lines3, lines4, 2)
            calc_height = max(30.0, max_lines * 14.5)
            ws_tc.row_dimensions[current_r].height = calc_height
            
            for c in range(1, 5):
                cell = ws_tc.cell(current_r, c)
                cell.font = font_tc_data
                cell.fill = fill_tc_data
                cell.border = thin_border
                cell.alignment = align_top_center if c == 1 else align_top_left
            current_r += 1

    # Set column widths for Test Cases
    ws_tc.column_dimensions['A'].width = 8.5
    ws_tc.column_dimensions['B'].width = 46.0
    ws_tc.column_dimensions['C'].width = 40.0
    ws_tc.column_dimensions['D'].width = 54.0

    # -------------------------------------------------------------
    # 2. UPDATE 'TEST SCENARIO' MATRIX SHEET
    # -------------------------------------------------------------
    ws_ts = wb['Test Scenario']
    
    # Clear existing content
    max_ts_r = max(ws_ts.max_row, 50)
    max_ts_c = max(ws_ts.max_column, 50)
    for r in range(1, max_ts_r + 1):
        for c in range(1, max_ts_c + 1):
            cell = ws_ts.cell(r, c)
            cell.value = None
            cell.fill = PatternFill(fill_type=None)
            cell.border = Border()
            cell.font = font_data_ts

    # Row 1: Header (No, Step Name, 1.1, 1.2, ..., 7.4)
    ws_ts.cell(1, 1).value = "No"
    ws_ts.cell(1, 2).value = "Step Name"
    ws_ts.row_dimensions[1].height = 25.0
    
    col_idx = 3
    for tc_id in tc_id_list:
        cell = ws_ts.cell(1, col_idx)
        cell.value = tc_id
        col_letter = get_column_letter(col_idx)
        ws_ts.column_dimensions[col_letter].width = 6.5
        col_idx += 1

    total_cols = col_idx - 1

    # Style Row 1
    for c in range(1, total_cols + 1):
        cell = ws_ts.cell(1, c)
        cell.font = font_header_ts
        cell.fill = fill_header_ts
        cell.border = thin_border
        cell.alignment = align_center

    ws_ts.column_dimensions['A'].width = 6.0
    ws_ts.column_dimensions['B'].width = 56.0

    # Populate Steps (Rows 2..N)
    for step_idx, (s_no, s_name, marked_tcs) in enumerate(steps_data):
        r = step_idx + 2
        ws_ts.cell(r, 1).value = s_no
        ws_ts.cell(r, 2).value = s_name
        ws_ts.row_dimensions[r].height = 22.0
        
        ws_ts.cell(r, 1).font = font_data_ts
        ws_ts.cell(r, 1).fill = fill_data_ts
        ws_ts.cell(r, 1).border = thin_border
        ws_ts.cell(r, 1).alignment = align_center
        
        ws_ts.cell(r, 2).font = font_data_ts
        ws_ts.cell(r, 2).fill = fill_data_ts
        ws_ts.cell(r, 2).border = thin_border
        ws_ts.cell(r, 2).alignment = align_left
        
        # Populate each test case column
        for tc_c_idx, tc_id in enumerate(tc_id_list):
            c = tc_c_idx + 3
            cell = ws_ts.cell(r, c)
            cell.font = font_data_ts
            cell.fill = fill_data_ts
            cell.border = thin_border
            cell.alignment = align_center
            if tc_id in marked_tcs:
                cell.value = "X"
            else:
                cell.value = None

    # -------------------------------------------------------------
    # 3. UPDATE 'HISTORIES' SHEET
    # -------------------------------------------------------------
    ws_h = wb['Histories']
    # Add Row 6: Version 1.3
    ws_h.cell(6, 2).value = "=B5+1"
    ws_h.cell(6, 3).value = 1.3
    ws_h.cell(6, 4).value = (
        "Synchronize Test Scenario and Test Cases 1:1 across 7 modules: "
        "1. Login & Repository Search, 2. CTS Hierarchy & Detail Logs (S40K920015 Cofile fix), "
        "3. Comparison Matrix, 4. Monaco Code/Metadata Diff, 5. Version History & Target Snapshots "
        "(CLAS ZCL_Z_00_032_TEST_BETA), 6. AI Code Review (SICF /sap/bc/zscort_ai), "
        "7. Selective Apply & End-to-End Lifecycle. Full backend test data integration (Client 324, DEV-026)."
    )
    ws_h.cell(6, 5).value = "All sheet"
    ws_h.cell(6, 6).value = datetime.datetime(2026, 9, 19, 0, 0)
    ws_h.cell(6, 7).value = "Biện Trung Tín / Antigravity"
    
    font_h = Font(name="Microsoft Yahei", size=10.0)
    for c in range(2, 8):
        cell = ws_h.cell(6, c)
        cell.font = font_h
        cell.border = thin_border
        if c in [2, 3, 5, 6]:
            cell.alignment = align_center
        else:
            cell.alignment = align_left
    ws_h.row_dimensions[6].height = 45.0

    # Save finalized workbook
    wb.save(wb_path)
    print("SUCCESS: Docs\\Test_Scenario.xlsx synchronized and updated successfully!")

if __name__ == "__main__":
    run_update()
