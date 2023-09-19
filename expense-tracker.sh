#!/bin/bash

# Define the SQLite database file
DATABASE_FILE="expense_tracker.db"

# Function to display the main menu
main_menu() {
    clear
    echo "Expense Tracker Main Menu"
    echo "1. Add Expense"
    echo "2. View Expense History"
    echo "3. Generate Reports"
    echo "4. Set Budget Alert"
    echo "5. Create Backup"
    echo "6. Restore Data from Backup"
    echo "7. Register User"
    echo "8. Login"
    echo "9. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            add_expense
            ;;
        2)
            view_expense_history
            ;;
        3)
            generate_reports_menu
            ;;
        4)
            set_budget_alert
            ;;
        5)
            create_backup
            ;;
        6)
            restore_data
            ;;
        7)
            register_user  # Option for user registration
            ;;
        8)
            authenticate_user  # Option for user login
            ;;
        9)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            main_menu
            ;;
    esac
}



# Function to add a new expense
add_expense() {
    clear
    echo "Add Expense"
    read -p "Date (YYYY-MM-DD): " date
    read -p "Description: " description
    read -p "Category: " category

    # Validate the input for amount (must be a positive number)
    while true; do
        read -p "Amount: " amount
        if [[ ! $amount =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$amount < 0" | bc -l) )); then
            echo "Invalid amount. Please enter a positive number."
        else
            break
        fi
    done

    # Ask the user for a budget limit for the expense category
    read -p "Budget Limit for Category '$category': " budget_limit

    # Ask the user for a category
    read -p "Category: " category

    # Ask the user for tags (comma-separated)
    read -p "Tags (comma-separated): " tags

    # Insert the validated expense and budget limit into the database
    if sqlite3 $DATABASE_FILE "INSERT INTO expenses (date, description, category, amount, budget_limit) VALUES ('$date', '$description', '$category', $amount, $budget_limit);" ; then
        echo "Expense added successfully!"
    else
        handle_database_error
    fi

    # Check if the expense exceeds the budget limit
    if (( $(echo "$amount > $budget_limit" | bc -l) )); then
        echo "Warning: Expense exceeds the budget limit for category '$category'!"
    fi

        # Insert the validated expense, category, and tags into the database
    # First, insert the category if it doesn't exist
    category_id=$(sqlite3 $DATABASE_FILE "INSERT OR IGNORE INTO categories (name) VALUES ('$category'); SELECT id FROM categories WHERE name = '$category';")
    
    # Split tags into an array
    IFS=',' read -ra tag_array <<< "$tags"
    
    # Insert tags into the tags table and get their IDs
    tag_ids=()
    for tag in "${tag_array[@]}"; do
        tag_id=$(sqlite3 $DATABASE_FILE "INSERT OR IGNORE INTO tags (name) VALUES ('$tag'); SELECT id FROM tags WHERE name = '$tag';")
        tag_ids+=("$tag_id")
    done

    # Insert the expense and its associations into the database
    sqlite3 $DATABASE_FILE "INSERT INTO expenses (date, description, amount, budget_limit, category_id) VALUES ('$date', '$description', $amount, $budget_limit, $category_id);"

    # Get the ID of the last inserted expense
    expense_id=$(sqlite3 $DATABASE_FILE "SELECT last_insert_rowid();")

    # Associate tags with the expense in the expense_tags table
    for tag_id in "${tag_ids[@]}"; do
        sqlite3 $DATABASE_FILE "INSERT INTO expense_tags (expense_id, tag_id) VALUES ($expense_id, $tag_id);"
    done

    echo "Expense added successfully!"
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to view expense history
view_expense_history() {
    clear
    echo "View Expense History"
    echo "1. View All Expenses"
    echo "2. View Expenses for a Specific Date"
    echo "3. View Expenses Within a Date Range"
    echo "4. View Expenses by Category"
    echo "5. Back"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            # Query the database for all expenses
            if sqlite3 $DATABASE_FILE "SELECT * FROM expenses;"; then
                # Display expenses
                echo "All Expenses"
            else
                handle_database_error
            fi
            ;;
        2)
            read -p "Enter the date (YYYY-MM-DD): " view_date
            # Query the database for expenses on a specific date
            if sqlite3 $DATABASE_FILE "SELECT * FROM expenses WHERE date = '$view_date';"; then
                # Display expenses
                echo "expenses on a specific date"
            else
                handle_database_error
            fi
            ;;
        3)
            read -p "Enter start date (YYYY-MM-DD): " start_date
            read -p "Enter end date (YYYY-MM-DD): " end_date
            # Query the database for expenses within a date range
            if sqlite3 $DATABASE_FILE "SELECT * FROM expenses WHERE date BETWEEN '$start_date' AND '$end_date';"; then
                echo "expenses within a date range"
            else
                handle_database_error
            fi
            ;;
        4)
            read -p "Enter the category: " category
            # Query the database for expenses by category
            if sqlite3 $DATABASE_FILE "SELECT * FROM expenses WHERE category = '$category';"; then
                echo "expenses by category"
            else
                handle_database_error
            fi
            ;;
        5)
            main_menu
            ;;
        *)
            echo "Invalid choice. Please try again."
            view_expense_history
            ;;
    esac

    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to generate reports
generate_reports_menu() {
    clear
    echo "Generate Reports"
    echo "1. Monthly Expense Summary"
    echo "2. Category-wise Expense Breakdown"
    echo "3. Back"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            generate_monthly_summary
            ;;
        2)
            generate_category_breakdown
            ;;
        3)
            main_menu
            ;;
        *)
            echo "Invalid choice. Please try again."
            generate_reports_menu
            ;;
    esac
}

# Function to generate a monthly expense summary
generate_monthly_summary() {
    clear
    echo "Monthly Expense Summary"
    read -p "Enter the year and month (YYYY-MM): " year_month

    # Query the database to calculate and display the monthly summary
    sqlite3 $DATABASE_FILE "SELECT strftime('%Y-%m', date) AS month, SUM(amount) AS total_expenses FROM expenses WHERE strftime('%Y-%m', date) = '$year_month' GROUP BY month;"
    
    read -p "Press Enter to return to the main menu..."
    generate_reports_menu
}

# Function to generate a category-wise expense breakdown
generate_category_breakdown() {
    clear
    echo "Category-wise Expense Breakdown"
    
    # Query the database to calculate and display category-wise expenses
    sqlite3 $DATABASE_FILE "SELECT category, SUM(amount) AS total_expenses FROM expenses GROUP BY category;"
    
    read -p "Press Enter to return to the main menu..."
    generate_reports_menu
}

# Function to set budget alerts
set_budget_alert() {
    clear
    echo "Set Budget Alert (TODO)"
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to create a backup of the database
create_backup() {
    clear
    echo "Creating a Database Backup"
    timestamp=$(date +'%Y%m%d%H%M%S')
    backup_file="backup_${timestamp}.db"
    cp "$DATABASE_FILE" "$backup_file"
    echo "Backup created: $backup_file"
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to restore data from a backup
restore_data() {
    clear
    echo "Restore Data from Backup"
    read -p "Enter the backup file name: " backup_file
    
    # Check if the backup file exists
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$DATABASE_FILE"
        echo "Data successfully restored from $backup_file."
    else
        echo "Backup file not found: $backup_file"
    fi
    
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to register a new user
register_user() {
    clear
    echo "User Registration"
    read -p "Enter your desired username: " username
    read -s -p "Enter your password: " password
    hashed_password=$(echo -n "$password" | sha256sum | awk '{print $1}')
    
    # Check if the username is available
    existing_user=$(sqlite3 $DATABASE_FILE "SELECT COUNT(*) FROM users WHERE username = '$username';")
    if [ "$existing_user" -eq 0 ]; then
        # Insert the new user into the database
        sqlite3 $DATABASE_FILE "INSERT INTO users (username, password) VALUES ('$username', '$hashed_password');"
        echo "User registered successfully!"
    else
        echo "Username already exists. Please choose a different username."
    fi
    
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to authenticate a user
authenticate_user() {
    clear
    echo "User Login"
    read -p "Enter your username: " username
    read -s -p "Enter your password: " password
    hashed_password=$(echo -n "$password" | sha256sum | awk '{print $1}')
    
    # Check if the provided username and password match
    valid_user=$(sqlite3 $DATABASE_FILE "SELECT COUNT(*) FROM users WHERE username = '$username' AND password = '$hashed_password';")
    if [ "$valid_user" -eq 1 ]; then
        echo "Authentication successful!"
        # You can set a variable or session token to track the authenticated user
    else
        echo "Authentication failed. Please check your username and password."
    fi
    
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Function to handle database errors
handle_database_error() {
    echo "An error occurred while accessing the database."
    echo "Please check your database connection and try again."
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Main loop
while true; do
    main_menu
done
