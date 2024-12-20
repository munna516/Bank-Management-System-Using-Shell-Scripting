#!/bin/bash

# Bank Management System with Admin/User modes, Account-level Passwords, Mode Switching, and Transaction History

# Declare files to store account details, passwords, and transaction history
BANK_DB="bank_records.txt"
PASSWORD_FILE="passwords.txt"
TRANSACTION_HISTORY="transaction_history.txt"

# Function to check if passwords are already set, if not, create them
initialize_passwords() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo "Setting up initial passwords for Admin and User."
        echo "Enter new Admin Password:"
        read -s admin_password
        echo "Enter new User Password:"
        read -s user_password
        echo "ADMIN_PASSWORD=$admin_password" > "$PASSWORD_FILE"
        echo "USER_PASSWORD=$user_password" >> "$PASSWORD_FILE"
        echo "Passwords set successfully."
    fi
    # Load passwords from the file
    source "$PASSWORD_FILE"
}

# Function to login and determine mode (Admin/User)
login() {
    echo "Select Mode:"
    echo "1. Admin"
    echo "2. User"
    read mode_choice

    if [ "$mode_choice" -eq 1 ]; then
        echo "Enter Admin Password:"
        read -s password
        if [ "$password" == "$ADMIN_PASSWORD" ]; then
            echo "Admin Login Successful!"
            ADMIN_MODE=1
        else
            echo "Incorrect Password! Exiting..."
            exit 1
        fi
    elif [ "$mode_choice" -eq 2 ]; then
        echo "Enter User Password:"
        read -s password
        if [ "$password" == "$USER_PASSWORD" ]; then
            echo "User Login Successful!"
            ADMIN_MODE=0
        else
            echo "Incorrect Password! Exiting..."
            exit 1
        fi
    else
        echo "Invalid Selection! Exiting..."
        exit 1
    fi
}

# Function to switch from User mode to Admin mode
switch_to_admin() {
    echo "Enter Admin Password to switch to Admin mode:"
    read -s password
    if [ "$password" == "$ADMIN_PASSWORD" ]; then
        echo "Switching to Admin mode..."
        ADMIN_MODE=1
    else
        echo "Incorrect Admin Password! Remaining in User mode."
    fi
}

# Function to switch from Admin mode to User mode
switch_to_user() {
    echo "Enter User Password to switch to User mode:"
    read -s password
    if [ "$password" == "$USER_PASSWORD" ]; then
        echo "Switching to User mode..."
        ADMIN_MODE=0
    else
        echo "Incorrect User Password! Remaining in Admin mode."
    fi
}

# Function to create an account (Admin only)
create_account() {
    # Ensure the file exists
    if [ ! -f "$BANK_DB" ]; then
        touch "$BANK_DB"
    fi

    if [ $ADMIN_MODE -eq 1 ]; then
        echo "Enter Account Number:"
        read acc_no

        # Check if account number already exists
        if grep -q "^$acc_no " "$BANK_DB"; then
            echo "Account Number $acc_no already exists. Cannot create a duplicate account."
            return
        fi

        echo "Enter Name:"
        read name
        echo "Enter Initial Deposit:"
        read deposit
        echo "Set Password for this account:"
        read -s acc_password

        echo "$acc_no $name $deposit $acc_password" >> "$BANK_DB"
        echo "Account created successfully!"
        echo "$acc_no Created account with initial deposit of $deposit" >> "$TRANSACTION_HISTORY"
    else
        echo "Access Denied! Only Admin can create accounts."
    fi
}
# Function to view account details with password verification
view_account() {
    echo "Enter Account Number:"
    read acc_no
    account=$(grep "^$acc_no " $BANK_DB)
    if [ -z "$account" ]; then
        echo "Account not found!"
    else
        echo "Enter Account Password:"
        read -s acc_password
        stored_password=$(echo $account | cut -d' ' -f4)

        if [ "$acc_password" == "$stored_password" ]; then
            echo "Account Details:"
            echo "Account Number: $(echo $account | cut -d' ' -f1)"
            echo "Name: $(echo $account | cut -d' ' -f2)"
            echo "Balance: $(echo $account | cut -d' ' -f3)"
        else
            echo "Incorrect password!"
        fi
    fi
}

# Function to view transaction history
view_transaction_history() {
    echo "Enter Account Number:"
    read acc_no
    echo "Enter Account Password:"
    read -s acc_password

    account=$(grep "^$acc_no " $BANK_DB)
    if [ -z "$account" ]; then
        echo "Account not found!"
    elif [ "$acc_password" == "$(echo $account | cut -d' ' -f4)" ]; then
        echo "Transaction History for Account Number $acc_no:"
        grep "^$acc_no" $TRANSACTION_HISTORY || echo "No transactions found."
    else
        echo "Incorrect password!"
    fi
}

# Function to deposit money (Admin and User with password verification)
deposit_money() {
    echo "Enter Account Number:"
    read acc_no
    echo "Enter Account Password:"
    read -s acc_password

    account=$(grep "^$acc_no " $BANK_DB)
    if [ -z "$account" ]; then
        echo "Account not found!"
    elif [ "$acc_password" != "$(echo $account | cut -d' ' -f4)" ]; then
        echo "Incorrect password!"
    else
        echo "Enter Deposit Amount:"
        read deposit
        balance=$(echo $account | cut -d' ' -f3)
        new_balance=$((balance + deposit))
        sed -i "/^$acc_no /c\\$acc_no $(echo $account | cut -d' ' -f2) $new_balance $acc_password" $BANK_DB
        echo "Deposit successful! New Balance: $new_balance"
        echo "$acc_no Deposited $deposit" >> $TRANSACTION_HISTORY
    fi
}

# Function to withdraw money (Admin and User with password verification)
withdraw_money() {
    echo "Enter Account Number:"
    read acc_no
    echo "Enter Account Password:"
    read -s acc_password

    account=$(grep "^$acc_no " $BANK_DB)
    if [ -z "$account" ]; then
        echo "Account not found!"
    elif [ "$acc_password" != "$(echo $account | cut -d' ' -f4)" ]; then
        echo "Incorrect password!"
    else
        echo "Enter Withdrawal Amount:"
        read withdrawal
        balance=$(echo $account | cut -d' ' -f3)
        if [ $withdrawal -gt $balance ]; then
            echo "Insufficient balance!"
        else
            new_balance=$((balance - withdrawal))
            sed -i "/^$acc_no /c\\$acc_no $(echo $account | cut -d' ' -f2) $new_balance $acc_password" $BANK_DB
            echo "Withdrawal successful! New Balance: $new_balance"
            echo "$acc_no Withdrew $withdrawal" >> $TRANSACTION_HISTORY
        fi
    fi
}

# Function for Admin to list all accounts
list_all_accounts() {
    if [ $ADMIN_MODE -eq 1 ]; then
        echo "All Account Details:"
        while IFS= read -r account; do
            acc_no=$(echo $account | cut -d' ' -f1)
            name=$(echo $account | cut -d' ' -f2)
            balance=$(echo $account | cut -d' ' -f3)
            echo "Account Number: $acc_no, Name: $name, Balance: $balance"
        done < $BANK_DB
    else
        echo "Access Denied! Only Admin can view all accounts."
    fi
}

transfer_money() {
    echo "Enter Sender Account Number:"
    read sender_acc_no
    echo "Enter Sender Account Password:"
    read -s sender_acc_password

    # Check if sender account exists
    sender_account=$(grep "^$sender_acc_no " $BANK_DB)
    if [ -z "$sender_account" ]; then
        echo "Sender account does not exist!"
        return
    fi

    # Verify sender's password
    stored_sender_password=$(echo $sender_account | cut -d' ' -f4)
    if [ "$sender_acc_password" != "$stored_sender_password" ]; then
        echo "Incorrect password for sender account!"
        return
    fi

    # Get receiver account number and check if it exists
    echo "Enter Receiver Account Number:"
    read receiver_acc_no
    receiver_account=$(grep "^$receiver_acc_no " $BANK_DB)
    if [ -z "$receiver_account" ]; then
        echo "Receiver account does not exist!"
        return
    fi

    # Prompt for transfer amount and verify balance
    echo "Enter Transfer Amount:"
    read transfer_amount
    sender_balance=$(echo $sender_account | cut -d' ' -f3)

    if [ $transfer_amount -gt $sender_balance ]; then
        echo "Insufficient balance in sender account!"
        return
    fi

    # Update balances for sender and receiver
    new_sender_balance=$((sender_balance - transfer_amount))
    receiver_balance=$(echo $receiver_account | cut -d' ' -f3)
    new_receiver_balance=$((receiver_balance + transfer_amount))

    # Update BANK_DB for both accounts
    sed -i "/^$sender_acc_no /c\\$sender_acc_no $(echo $sender_account | cut -d' ' -f2) $new_sender_balance $stored_sender_password" $BANK_DB
    sed -i "/^$receiver_acc_no /c\\$receiver_acc_no $(echo $receiver_account | cut -d' ' -f2) $new_receiver_balance $(echo $receiver_account | cut -d' ' -f4)" $BANK_DB

    # Log transaction in TRANSACTION_HISTORY
    echo "$sender_acc_no Transferred $transfer_amount to $receiver_acc_no" >> $TRANSACTION_HISTORY
    echo "Transfer successful! New Balance for Sender: $new_sender_balance"
}

# Main Program Execution
initialize_passwords
login

while true; do
    # Display mode title
    if [ $ADMIN_MODE -eq 1 ]; then
        echo "========= Admin Mode ========="
    else
        echo "========= User Mode ========="
    fi
    
    echo "1. Create Account (Admin only)"
    echo "2. View Account"
    echo "3. Deposit Money"
    echo "4. Withdraw Money"
    echo "5. List All Accounts (Admin only)"
    echo "6. View Transaction History"
    echo "7. Switch to Admin Mode (if logged in as User)"
    echo "8. Switch to User Mode (if logged in as Admin)"
    echo "9. Transfer Money"
    echo "10. Exit"
    echo "================================"
    echo "Choose an option:"
    read option

    case $option in
        1) create_account ;;
        2) view_account ;;
        3) deposit_money ;;
        4) withdraw_money ;;
        5) list_all_accounts ;;
        6) view_transaction_history ;;
        7) if [ $ADMIN_MODE -eq 0 ]; then switch_to_admin; else echo "Already in Admin mode."; fi ;;
        8) if [ $ADMIN_MODE -eq 1 ]; then switch_to_user; else echo "Already in User mode."; fi ;;
        9) transfer_money ;;
        10) echo "Exiting the system..."; exit ;;
        *) echo "Invalid option! Please try again." ;;
    esac
done
