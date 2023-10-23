*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

# Import necessary libraries for the tasks
Library             RPA.Browser.Selenium
Library             RPA.Tables
Library             RPA.PDF
Library             DateTime
Library             Collections
Library             String
Library             zipfile
Library             RPA.FileSystem
Library             RPA.Archive
Library             OperatingSystem
Library             RPA.HTTP


*** Variables ***
# Define necessary variables for URLs, file paths, and elements
${URL_CVS_DOWNLOAD}             https://robotsparebinindustries.com/orders.csv
${URL_ROBOT_ORDER}              https://robotsparebinindustries.com/#/robot-order
${FILE_PATH}                    ${CURDIR}${/}orders.csv
${BUTTOM_ORDER}                 xpath=//button[@id='order']
${BUTTOM_ORDER_ANOTHER}         xpath=//button[contains(@id,'order-another')]
${RECEIPT_ELEMENT}              xpath=//h3[contains(.,'Receipt')]
${RECEIPT_FILENAME_PREFIX}      receipt_
${ROBOT_DIV_XPATH}              //div[@id='robot-preview-image']
${RECEIPTS_DIR}                 ${CURDIR}


*** Tasks ***
# Main task definition
Order Robots from RobotSpareBin Industries Inc - Lvl2 - Tejus
    Open Robot Orders Website
    Get Orders
    Handle Robot Orders
    Archive Output PDFs
    [Teardown]    Close RobotSpareBin Browser


*** Keywords ***
# Define keywords for various operations
Open Robot Orders Website
    # Keyword to open the website with robot orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True

Get Orders
    # Keyword to prepare directory for receipts and check if file exists
    Prepare Receipts Directory
    Wait Until Keyword Succeeds    5x    2s    OperatingSystem.File Should Exist    ${FILE_PATH}

Handle Robot Orders
    # Keyword to handle the process of ordering robots
    Open Available Browser    ${URL_ROBOT_ORDER}    maximized=True
    Close Annoying Modal
    ${data_table}=    Read CSV Data
    ${row_index}=    Set Variable    0
    FOR    ${row}    IN    @{data_table}
        ${row_index}=    Evaluate    ${row_index} + 1
        Fill Order Form    ${row}[Head]    ${row}[Body]    ${row}[Legs]    ${row}[Address]    ${row_index}
    END
    Log To Console    Receipts archived in: ${RECEIPTS_DIR_TIMESTAMPED}.zip
    # Close Browser

Read CSV Data
    # Keyword to read data from the CSV file
    ${table}=    Read Table From CSV    ${FILE_PATH}
    RETURN    ${table}

Archive Output PDFs
    # Keyword to archive the output PDFs into a ZIP file and remove the directory
    Archive Folder With Zip
    ...    folder=${RECEIPTS_DIR_TIMESTAMPED}
    ...    archive_name=${RECEIPTS_DIR_TIMESTAMPED}.zip
    ...    recursive=True
    OperatingSystem.Remove Directory    ${RECEIPTS_DIR_TIMESTAMPED}    recursive=True

Close Annoying Modal
    # Keyword to close modal that might block interaction with the page
    Click Button    xpath=//button[contains(text(),'OK')]

Fill Order Form
    # Keyword to fill the order form on the webpage
    [Arguments]    ${head}    ${body}    ${legs}    ${shipping_address}    ${row_index}
    ${receipt_present}=    Set Variable    ${FALSE}
    ${max_attempts}=    Set Variable    10

    FOR    ${iteration}    IN RANGE    1    ${max_attempts}
        IF    ${receipt_present}    BREAK
        Select From List By Value    id=head    ${head}
        Click Element When Clickable    xpath://label[contains(@for,'id-body-${body}')]
        Input Text    //input[contains(@placeholder,'Enter the part number for the legs')]    ${legs}
        Input Text    //input[contains(@id,'address')]    ${shipping_address}
        Wait Until Element Is Visible    ${BUTTOM_ORDER}
        Wait Until Element Is Enabled    ${BUTTOM_ORDER}
        # Click Button    ${BUTTOM_ORDER}
        # Click Button When Visible    ${BUTTOM_ORDER}
        Click Element When Clickable    ${BUTTOM_ORDER}
        ${receipt_present}=    Run Keyword And Return Status    Element Should Be Visible    ${RECEIPT_ELEMENT}
        Capture Page Screenshot
    END
    Continue Normally    ${row_index}

Continue Normally
    # Keyword to continue the process after order form submission
    [Arguments]    ${row_index}
    Capture Page Screenshot
    ${current_timestamp}=    Capture Receipt As PDF    ${row_index}
    Click Button When Visible    ${BUTTOM_ORDER_ANOTHER}
    Close Annoying Modal

Capture Receipt As PDF
    # Keyword to capture the receipt as a PDF file
    [Arguments]    ${row_index}
    Wait Until Element Is Visible    ${RECEIPT_ELEMENT}
    ${receipt_html}=    Get Element Attribute    ${RECEIPT_ELEMENT}/..    outerHTML
    ${complete_html}=    Set Variable    <div style="text-align:center;">${receipt_html}</div>
    ${robot_div_img_filename}=    Set Variable    robot_div_${row_index}.png
    # Capture Element Screenshot    ${ROBOT_DIV_XPATH}    filename=${robot_div_img_filename}
    Screenshot    ${ROBOT_DIV_XPATH}    filename=${robot_div_img_filename}
    ${robot_img_tag}=    Set Variable
    ...    <img src="${robot_div_img_filename}" alt="Robot Image" style="width:70%; margin:auto;" />
    ${complete_html}=    Set Variable    ${complete_html}<div style="text-align:center;">${robot_img_tag}</div>
    ${current_timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${pdf_filename}=    Set Variable    receipt_${row_index}_${current_timestamp}.pdf
    ${pdf_fullpath}=    Set Variable    ${RECEIPTS_DIR_TIMESTAMPED}${/}${pdf_filename}
    RPA.PDF.Html To Pdf    ${complete_html}    ${pdf_fullpath}
    OperatingSystem.Remove File    ${robot_div_img_filename}
    Log    PDF saved at: ${pdf_fullpath}
    RETURN    ${pdf_fullpath}

Prepare Receipts Directory
    # Keyword to prepare the directory for saving receipts
    ${TIMESTAMP}=    Get Current Timestamp
    Set Global Variable    ${TIMESTAMP}
    # ${RECEIPTS_DIR_TIMESTAMPED}=    Set Variable    ${CURDIR}${/}receipts_${TIMESTAMP}
    ${RECEIPTS_DIR_TIMESTAMPED}=    Set Variable    ${OUTPUT_DIR}${/}receipts_${TIMESTAMP}
    OperatingSystem.Create Directory    ${RECEIPTS_DIR_TIMESTAMPED}
    Set Global Variable    ${RECEIPTS_DIR_TIMESTAMPED}
    RETURN    ${RECEIPTS_DIR_TIMESTAMPED}

Get Current Timestamp
    # Keyword to get the current timestamp
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    RETURN    ${timestamp}

Close RobotSpareBin Browser
    # Keyword to close the browser
    Close Browser
