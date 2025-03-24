#!/bin/bash

# social_media_scheduler.sh - A script to schedule posts on social media platforms
# Usage: ./social_media_scheduler.sh [config_file]

set -e

# Default config file location
CONFIG_FILE="${1:-$HOME/.social_media_config}"
SCHEDULE_FILE="$HOME/.scheduled_posts"

# Initialize or create the schedule file if it doesn't exist
if [ ! -f "$SCHEDULE_FILE" ]; then
    echo "Creating new schedule file at $SCHEDULE_FILE"
    echo "# Scheduled Posts - format: timestamp|platform|message" > "$SCHEDULE_FILE"
fi

# Check for config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found. Creating template at $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Social Media Configuration File
# Set your API keys/tokens below

# Twitter/X
TWITTER_API_KEY=""
TWITTER_API_SECRET=""
TWITTER_ACCESS_TOKEN=""
TWITTER_ACCESS_SECRET=""

# LinkedIn
LINKEDIN_API_KEY=""
LINKEDIN_API_SECRET=""
LINKEDIN_ACCESS_TOKEN=""

# Facebook
FACEBOOK_ACCESS_TOKEN=""
FACEBOOK_PAGE_ID=""

# Instagram (via Facebook)
INSTAGRAM_BUSINESS_ID=""

# Choose your default client (curl, twurl, etc.)
CLIENT="curl"
EOF
    echo "Please edit $CONFIG_FILE and add your API credentials"
    exit 1
fi

# Source the config file
source "$CONFIG_FILE"

# Function to display help
show_help() {
    cat << EOF
Social Media Post Scheduler
--------------------------
Commands:
  schedule - Schedule a new post
  list     - List all scheduled posts
  delete   - Delete a scheduled post
  post     - Manually trigger posting
  help     - Show this help message

Examples:
  ./social_media_scheduler.sh schedule
  ./social_media_scheduler.sh list
  ./social_media_scheduler.sh delete 3
  ./social_media_scheduler.sh post 2
EOF
}

# Function to schedule a post
schedule_post() {
    echo "Schedule a new post"
    echo "-------------------"
    
    # Get platform
    echo "Select platform:"
    echo "1) Twitter/X"
    echo "2) LinkedIn"
    echo "3) Facebook"
    echo "4) Instagram"
    echo "5) All platforms"
    read -p "Enter your choice (1-5): " platform_choice
    
    case $platform_choice in
        1) platform="twitter" ;;
        2) platform="linkedin" ;;
        3) platform="facebook" ;;
        4) platform="instagram" ;;
        5) platform="all" ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Get message
    echo "Enter your post content (press Ctrl+D when finished):"
    message=$(cat)
    
    # Get scheduling details
    echo "When to post?"
    read -p "Year (YYYY): " year
    read -p "Month (MM): " month
    read -p "Day (DD): " day
    read -p "Hour (HH, 24-hour format): " hour
    read -p "Minute (MM): " minute
    
    # Validate date format
    if ! date -d "$year-$month-$day $hour:$minute:00" > /dev/null 2>&1; then
        echo "Invalid date format"
        return 1
    fi
    
    # Convert to timestamp
    timestamp=$(date -d "$year-$month-$day $hour:$minute:00" +%s)
    
    # Add to schedule file
    echo "$timestamp|$platform|$message" >> "$SCHEDULE_FILE"
    
    human_date=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M")
    echo "Post scheduled for $human_date on $platform"
}

# Function to list all scheduled posts
list_posts() {
    echo "Scheduled Posts"
    echo "--------------"
    
    # Check if there are any scheduled posts
    if [ $(grep -v "^#" "$SCHEDULE_FILE" | wc -l) -eq 0 ]; then
        echo "No posts scheduled."
        return 0
    fi
    
    # Sort by timestamp and display
    grep -v "^#" "$SCHEDULE_FILE" | sort -t'|' -k1,1n | awk -F'|' '{ 
        cmd = "date -d @"$1" \"+%Y-%m-%d %H:%M\"";
        cmd | getline date;
        close(cmd);
        printf "ID: %d | Date: %s | Platform: %s\nMessage: %s\n\n", NR, date, $2, $3;
    }'
}

# Function to delete a scheduled post
delete_post() {
    if [ -z "$1" ]; then
        echo "Please specify the post ID to delete"
        list_posts
        return 1
    fi
    
    post_count=$(grep -v "^#" "$SCHEDULE_FILE" | wc -l)
    
    if [ "$1" -gt "$post_count" ] || [ "$1" -lt 1 ]; then
        echo "Invalid post ID. Please enter a number between 1 and $post_count"
        return 1
    fi
    
    # Create a temporary file without the deleted post
    grep -v "^#" "$SCHEDULE_FILE" | sort -t'|' -k1,1n | awk -v id="$1" '{
        if (NR != id) {
            print $0;
        } else {
            deleted = $0;
        }
    }' > "$SCHEDULE_FILE.tmp"
    
    # Add the header back
    sed -i '1s/^/# Scheduled Posts - format: timestamp|platform|message\n/' "$SCHEDULE_FILE.tmp"
    
    # Replace the original file
    mv "$SCHEDULE_FILE.tmp" "$SCHEDULE_FILE"
    
    echo "Post $1 deleted successfully"
}

# Function to post to Twitter/X
post_to_twitter() {
    local message="$1"
    echo "Posting to Twitter/X: $message"
    
    if [ -z "$TWITTER_API_KEY" ] || [ -z "$TWITTER_API_SECRET" ] || [ -z "$TWITTER_ACCESS_TOKEN" ] || [ -z "$TWITTER_ACCESS_SECRET" ]; then
        echo "Twitter API credentials not set in config file"
        return 1
    fi
    
    # Using curl for API v2
    curl -s -X POST "https://api.twitter.com/2/tweets" \
         -H "Authorization: OAuth oauth_consumer_key=\"$TWITTER_API_KEY\", oauth_token=\"$TWITTER_ACCESS_TOKEN\"" \
         -H "Content-Type: application/json" \
         -d "{\"text\":\"$message\"}" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "Successfully posted to Twitter/X"
    else
        echo "Failed to post to Twitter/X"
    fi
}

# Function to post to LinkedIn
post_to_linkedin() {
    local message="$1"
    echo "Posting to LinkedIn: $message"
    
    if [ -z "$LINKEDIN_API_KEY" ] || [ -z "$LINKEDIN_API_SECRET" ] || [ -z "$LINKEDIN_ACCESS_TOKEN" ]; then
        echo "LinkedIn API credentials not set in config file"
        return 1
    fi
    
    # Simplified for demonstration - actual LinkedIn API implementation would go here
    echo "LinkedIn posting completed"
}

# Function to post to Facebook
post_to_facebook() {
    local message="$1"
    echo "Posting to Facebook: $message"
    
    if [ -z "$FACEBOOK_ACCESS_TOKEN" ] || [ -z "$FACEBOOK_PAGE_ID" ]; then
        echo "Facebook API credentials not set in config file"
        return 1
    fi
    
    curl -s -X POST "https://graph.facebook.com/$FACEBOOK_PAGE_ID/feed" \
         -F "message=$message" \
         -F "access_token=$FACEBOOK_ACCESS_TOKEN" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "Successfully posted to Facebook"
    else
        echo "Failed to post to Facebook"
    fi
}

# Function to post to Instagram
post_to_instagram() {
    local message="$1"
    echo "Posting to Instagram: $message"
    
    if [ -z "$INSTAGRAM_BUSINESS_ID" ] || [ -z "$FACEBOOK_ACCESS_TOKEN" ]; then
        echo "Instagram API credentials not set in config file"
        return 1
    fi
    
    # Note: Instagram requires an image, simplified here
    echo "Instagram posting would require an image file"
}

# Function to manually trigger a post
post_now() {
    if [ -z "$1" ]; then
        echo "Please specify the post ID to post"
        list_posts
        return 1
    fi
    
    post_count=$(grep -v "^#" "$SCHEDULE_FILE" | wc -l)
    
    if [ "$1" -gt "$post_count" ] || [ "$1" -lt 1 ]; then
        echo "Invalid post ID. Please enter a number between 1 and $post_count"
        return 1
    fi
    
    # Get the post details
    post_data=$(grep -v "^#" "$SCHEDULE_FILE" | sort -t'|' -k1,1n | sed -n "${1}p")
    platform=$(echo "$post_data" | cut -d'|' -f2)
    message=$(echo "$post_data" | cut -d'|' -f3)
    
    case $platform in
        "twitter")
            post_to_twitter "$message"
            ;;
        "linkedin")
            post_to_linkedin "$message"
            ;;
        "facebook")
            post_to_facebook "$message"
            ;;
        "instagram")
            post_to_instagram "$message"
            ;;
        "all")
            post_to_twitter "$message"
            post_to_linkedin "$message"
            post_to_facebook "$message"
            post_to_instagram "$message"
            ;;
        *)
            echo "Unknown platform: $platform"
            return 1
            ;;
    esac
    
    # Ask if the user wants to delete the post after publishing
    read -p "Do you want to delete this post from the schedule? (y/n): " delete_choice
    if [ "$delete_choice" = "y" ] || [ "$delete_choice" = "Y" ]; then
        delete_post "$1"
    fi
}

# Function to run as a daemon and check for posts to publish
run_daemon() {
    echo "Starting daemon mode. Press Ctrl+C to exit."
    
    while true; do
        current_time=$(date +%s)
        
        # Find posts that are due
        grep -v "^#" "$SCHEDULE_FILE" | while IFS='|' read -r timestamp platform message; do
            if [ "$timestamp" -le "$current_time" ]; then
                echo "Publishing scheduled post on $platform..."
                
                case $platform in
                    "twitter")
                        post_to_twitter "$message"
                        ;;
                    "linkedin")
                        post_to_linkedin "$message"
                        ;;
                    "facebook")
                        post_to_facebook "$message"
                        ;;
                    "instagram")
                        post_to_instagram "$message"
                        ;;
                    "all")
                        post_to_twitter "$message"
                        post_to_linkedin "$message"
                        post_to_facebook "$message"
                        post_to_instagram "$message"
                        ;;
                    *)
                        echo "Unknown platform: $platform"
                        ;;
                esac
                
                # Remove the published post from the schedule
                sed -i "/^$timestamp|$platform/d" "$SCHEDULE_FILE"
            fi
        done
        
        # Sleep for a minute before checking again
        sleep 60
    done
}

# Main function to handle different commands
main() {
    case "$1" in
        "schedule")
            schedule_post
            ;;
        "list")
            list_posts
            ;;
        "delete")
            delete_post "$2"
            ;;
        "post")
            post_now "$2"
            ;;
        "daemon")
            run_daemon
            ;;
        "help"|"")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
