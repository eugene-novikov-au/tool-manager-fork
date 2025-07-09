

#
# Read a csv string, and assign the name/values to the passed in array
#
# $1 - csv string
# $2 - array reference
#
_tm::io::csv::to_array() {
    local csv_string="$1"
    local array_name="$2"
    local pair key value

    # read each name/value pairs
    IFS=',' read -ra pairs <<< "$csv_string"
    for pair in "${pairs[@]}"; do
        # Trim leading/trailing whitespace from the pair
        pair="${pair#"${pair%%[![:space:]]*}"}"
        pair="${pair%"${pair##*[![:space:]]}"}"
        # Split on first '=' only
        IFS='=' read -r key value <<< "$pair"
        # Assign to the array (using eval for dynamic array name)
        eval "$array_name"[\""$key"\"]=\""$value"\"
    done
}