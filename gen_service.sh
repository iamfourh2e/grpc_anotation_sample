#!/bin/bash

# Usage: ./gen_service.sh ServiceName "field1:type1,field2:type2,..."
#        ./gen_service.sh remove ServiceName
#        ./gen_service.sh add-rpc ServiceName RpcName "req_field1:type,..." "res_field1:type,..." "http=METHOD:/path" ["body=*"]
#        ./gen_service.sh add-nested ServiceName field_name "nested_field1:type,..." [repeated] [MessageName]

set -e

# Cleanup any temporary proto artifacts on exit
cleanup() {
  rm -f proto/*.proto.tmp 2>/dev/null || true
  rm -f proto/*.tmp 2>/dev/null || true
}
trap cleanup EXIT

# Determine module path from go.mod
MODULE_PATH="$(awk '/^module /{print $2}' go.mod 2>/dev/null)"
if [ -z "$MODULE_PATH" ]; then
  echo "Error: Could not read module path from go.mod. Please run this script in the repository root." >&2
  exit 1
fi

# Helper function to pluralize service names
pluralize() {
  local word="$1"
  local last_char="${word: -1}"
  local second_last_char="${word: -2:1}"
  
  # Handle special cases
  case "$word" in
    Story) echo "Stories" ;;
    Category) echo "Categories" ;;
    Country) echo "Countries" ;;
    City) echo "Cities" ;;
    Family) echo "Families" ;;
    Company) echo "Companies" ;;
    Baby) echo "Babies" ;;
    Lady) echo "Ladies" ;;
    Party) echo "Parties" ;;
    Study) echo "Studies" ;;
    Theory) echo "Theories" ;;
    History) echo "Histories" ;;
    Mystery) echo "Mysteries" ;;
    Discovery) echo "Discoveries" ;;
    Library) echo "Libraries" ;;
    Factory) echo "Factories" ;;
    Memory) echo "Memories" ;;
    Victory) echo "Victories" ;;
    Century) echo "Centuries" ;;
    Gallery) echo "Galleries" ;;
    Salary) echo "Salaries" ;;
    Boundary) echo "Boundaries" ;;
    Commentary) echo "Commentaries" ;;
    Dictionary) echo "Dictionaries" ;;
    Laboratory) echo "Laboratories" ;;
    Necessary) echo "Necessaries" ;;
    Primary) echo "Primaries" ;;
    Secondary) echo "Secondaries" ;;
    Temporary) echo "Temporaries" ;;
    Voluntary) echo "Voluntaries" ;;
    # Words ending in 'y' preceded by a consonant -> 'ies'
    *y)
      if [[ ! "$second_last_char" =~ [aeiou] ]]; then
        echo "${word%y}ies"
      else
        echo "${word}s"
      fi
      ;;
    # Words ending in 's', 'sh', 'ch', 'x', 'z' -> 'es'
    *s|*sh|*ch|*x|*z)
      echo "${word}es"
      ;;
    # Words ending in 'f' or 'fe' -> 'ves' (common cases)
    *f)
      case "$word" in
        Leaf|Life|Knife|Wolf|Calf|Half|Self|Shelf|Thief|Wife)
          echo "${word%f}ves"
          ;;
        *)
          echo "${word}s"
          ;;
      esac
      ;;
    *fe)
      case "$word" in
        Life|Knife|Wife)
          echo "${word%fe}ves"
          ;;
        *)
          echo "${word}s"
          ;;
      esac
      ;;
    # Default: just add 's'
    *)
      echo "${word}s"
      ;;
  esac
}

# Helper to normalize field types (placed early so all subcommands can use it)
normalize_type() {
  local t="$1"
  local tlc="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  case "$tlc" in
    string|bool|bytes|int32|int64|sint32|sint64|uint32|uint64|fixed32|fixed64|sfixed32|sfixed64|float|double)
      echo "$tlc"; return 0 ;;
    timestamp|datetime|date)
      echo "google.protobuf.Timestamp"; return 0 ;;
  esac
  local tlc_lower="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  if [ "$tlc_lower" = "google.protobuf.timestamp" ]; then
    echo "google.protobuf.Timestamp"; return 0
  fi
  local first="$(echo "${t:0:1}" | tr '[:lower:]' '[:upper:]')"
  echo "${first}${t:1}"
}

if [ "$1" = "remove" ]; then
  if [ -z "$2" ]; then
    echo "Usage: $0 remove ServiceName"
    exit 1
  fi
  SERVICE_NAME_RAW="$2"
  SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
  PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
  GO_FILE="services/${SERVICE_NAME_LC}.go"
  GRPC_GO="server/grpc.go"
  GATEWAY_GO="server/gateway.go"
  GRPC_REG="pb.Register${SERVICE_NAME}ServiceServer(grpcServer, services.New${SERVICE_NAME}Service())"
  GATEWAY_REG="pb.Register${SERVICE_NAME}ServiceHandler(ctx, mux, conn)"

  # Remove proto file
  if [ -f "$PROTO_FILE" ]; then
    rm "$PROTO_FILE"
    echo "Removed proto file: $PROTO_FILE"
  else
    echo "Proto file not found: $PROTO_FILE"
  fi

  # Remove Go service file
  if [ -f "$GO_FILE" ]; then
    rm "$GO_FILE"
    echo "Removed Go service file: $GO_FILE"
  else
    echo "Go service file not found: $GO_FILE"
  fi

  # Remove model file
  MODEL_FILE="models/${SERVICE_NAME_LC}.go"
  if [ -f "$MODEL_FILE" ]; then
    rm "$MODEL_FILE"
    echo "Removed model file: $MODEL_FILE"
  else
    echo "Model file not found: $MODEL_FILE"
  fi

  # Remove registration from grpc.go
  GRPC_REG_REGEX="pb\\.Register${SERVICE_NAME}ServiceServer\\(grpcServer,[[:space:]]*services\\.New${SERVICE_NAME}Service\\([^)]*\\)\\)"
  if grep -E -q "$GRPC_REG_REGEX" "$GRPC_GO"; then
    sed -E -i '' "/$GRPC_REG_REGEX/d" "$GRPC_GO"
    echo "Removed gRPC registration from $GRPC_GO"
  else
    echo "gRPC registration not found in $GRPC_GO"
  fi

  # Remove registration from gateway.go
  if grep -q "$GATEWAY_REG" "$GATEWAY_GO"; then
    # Remove the entire if block for this registration
    sed -i '' "/if err = $GATEWAY_REG; err != nil {/,/}/d" "$GATEWAY_GO"
    echo "Removed gateway registration from $GATEWAY_GO"
  else
    echo "Gateway registration not found in $GATEWAY_GO"
  fi

  echo "Service $SERVICE_NAME removed."
  exit 0
fi

# Add a new RPC to an existing service and proto
if [ "$1" = "add-rpc" ]; then
  # Args: add-rpc ServiceName RpcName "req_fields" "res_fields" "http=METHOD:/path" ["body=*"]
  if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
    echo "Usage: $0 add-rpc ServiceName RpcName \"req_field1:type,...\" \"res_field1:type,...\" \"http=METHOD:/path\" [\"body=*\"]" >&2
    exit 1
  fi

  SERVICE_NAME_RAW="$2"
  RPC_NAME_RAW="$3"
  REQ_FIELDS_RAW="$4"
  RES_FIELDS_RAW="$5"
  HTTP_SPEC_RAW="$6"
  BODY_SPEC_RAW="$7"

  SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
  PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
  GO_FILE="services/${SERVICE_NAME_LC}.go"

  if [ ! -f "$PROTO_FILE" ]; then
    echo "Proto file not found: $PROTO_FILE" >&2
    exit 1
  fi

  # Extract METHOD and PATH from http=METHOD:/path
  if [[ "$HTTP_SPEC_RAW" =~ ^http=([A-Za-z]+):(.*)$ ]]; then
    HTTP_METHOD="$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    HTTP_PATH="${BASH_REMATCH[2]}"
  else
    echo "Invalid HTTP spec. Expected 'http=METHOD:/path'" >&2
    exit 1
  fi

  HTTP_BODY=""
  if [ -n "$BODY_SPEC_RAW" ]; then
    if [[ "$BODY_SPEC_RAW" =~ ^body=(.*)$ ]]; then
      HTTP_BODY="${BASH_REMATCH[1]}"
    else
      echo "Invalid body spec. Expected 'body=*' or 'body=data'" >&2
      exit 1
    fi
  fi

  # Helpers re-used: normalize_type and snake_to_camel exist below; re-implement small builder here for fields
  build_fields_block() {
    local FIELDS_RAW_STR="$1"
    local TIMESTAMP_FLAG_VAR="$2"
    local LINES=""
    local NUM=1
    IFS=',' read -ra FIELDS_ARR <<< "$FIELDS_RAW_STR"
    for FIELD in "${FIELDS_ARR[@]}"; do
      local RAW_TRIMMED="$(echo "$FIELD" | xargs)"
      [ -z "$RAW_TRIMMED" ] && continue
      local NAME=""
      local TYPE_RAW=""
      local IS_REPEATED=0
      if [[ "$RAW_TRIMMED" == *:* ]]; then
        NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
        TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
        case "$TYPE_RAW" in
          repeated\ *) IS_REPEATED=1; TYPE_RAW="${TYPE_RAW#repeated }" ;;
          Repeated\ *) IS_REPEATED=1; TYPE_RAW="${TYPE_RAW#Repeated }" ;;
        esac
      else
        if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
          IS_REPEATED=1
          TYPE_RAW="${BASH_REMATCH[1]}"
          NAME="${BASH_REMATCH[2]}"
        else
          echo "Invalid field format in '$RAW_TRIMMED'" >&2
          exit 1
        fi
      fi
      local TYPE_NORM
      TYPE_NORM="$(normalize_type "$TYPE_RAW")"
      if [ "$TYPE_NORM" = "google.protobuf.Timestamp" ]; then
        eval "$TIMESTAMP_FLAG_VAR=1"
      fi
      if [ $IS_REPEATED -eq 1 ]; then
        LINES+="  repeated ${TYPE_NORM} ${NAME} = ${NUM};\n"
      else
        LINES+="  ${TYPE_NORM} ${NAME} = ${NUM};\n"
      fi
      NUM=$((NUM+1))
    done
    echo -e "$LINES"
  }

  RPC_NAME="$(echo "$RPC_NAME_RAW" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  REQ_MSG_NAME="${RPC_NAME}Request"
  RES_MSG_NAME="${RPC_NAME}Response"

  TS_USED=0
  REQ_FIELDS_BLOCK="$(build_fields_block "$REQ_FIELDS_RAW" TS_USED)"
  RES_FIELDS_BLOCK="$(build_fields_block "$RES_FIELDS_RAW" TS_USED)"

  # Ensure timestamp import exists if needed
  if [ "$TS_USED" -eq 1 ] && ! grep -q 'google/protobuf/timestamp.proto' "$PROTO_FILE"; then
    # Insert after annotations import
    if grep -q 'import "google/api/annotations.proto";' "$PROTO_FILE"; then
      sed -i '' '/import "google\/api\/annotations.proto";/a\
import "google/protobuf/timestamp.proto";
' "$PROTO_FILE"
    else
      # Fallback: add near top
      sed -i '' '1,/^package pb;/!b; /^package pb;/a\
\
import "google/protobuf/timestamp.proto";
' "$PROTO_FILE"
    fi
  fi

  # Append messages to the end of proto (before service insertion to keep things simple)
  {
    echo ""
    echo "message ${REQ_MSG_NAME} {"
    [ -n "$REQ_FIELDS_BLOCK" ] && echo -e "$REQ_FIELDS_BLOCK"
    echo "}"
    echo "message ${RES_MSG_NAME} {"
    [ -n "$RES_FIELDS_BLOCK" ] && echo -e "$RES_FIELDS_BLOCK"
    echo "}"
  } >> "$PROTO_FILE"

  # Build HTTP annotation
  HTTP_OPTION="option (google.api.http) = { ${HTTP_METHOD}: \"${HTTP_PATH}\"";
  if [ -n "$HTTP_BODY" ]; then
    HTTP_OPTION+=" body: \"${HTTP_BODY}\"";
  fi
  HTTP_OPTION+=" };"

  # Insert RPC into service block using awk
  TMP_PROTO="${PROTO_FILE}.tmp"
  awk -v svc="${SERVICE_NAME}Service" -v rpc="${RPC_NAME}" -v req="${REQ_MSG_NAME}" -v res="${RES_MSG_NAME}" -v httpopt="${HTTP_OPTION}" '
    BEGIN { in_svc=0 }
    {
      if ($0 ~ "^service "svc" \\{") { in_svc=1; print; next }
      if (in_svc==1 && $0 ~ /^\}$/) {
        print "  rpc "rpc"("req") returns ("res") {";
        print "    "httpopt;
        print "  }";
        in_svc=2;
      }
      print $0
    }
  ' "$PROTO_FILE" > "$TMP_PROTO"
  mv "$TMP_PROTO" "$PROTO_FILE"

  echo "Added RPC ${RPC_NAME} to service ${SERVICE_NAME} in $PROTO_FILE"

  # Append Go method stub if missing
  if [ -f "$GO_FILE" ]; then
    if ! grep -q "func (s \*${SERVICE_NAME}Service) ${RPC_NAME}(" "$GO_FILE"; then
      cat >> "$GO_FILE" <<EOF

func (s *${SERVICE_NAME}Service) ${RPC_NAME}(ctx context.Context, req *pb.${REQ_MSG_NAME}) (*pb.${RES_MSG_NAME}, error) {
	return &pb.${RES_MSG_NAME}{}, nil
}
EOF
      echo "Appended Go stub to $GO_FILE"
    else
      echo "Go stub already exists in $GO_FILE"
    fi
  else
    echo "Warning: Go service file not found: $GO_FILE. Create method manually."
  fi

  echo "Don't forget to run: make proto"
  exit 0
fi

# Add a nested message type and field to an existing service proto and model
if [ "$1" = "add-nested" ]; then
  # Args: add-nested ServiceName field_name "fields" [repeated] [MessageName]
  if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "Usage: $0 add-nested ServiceName field_name \"field1:type,...\" [repeated] [MessageName]" >&2
    exit 1
  fi

  SERVICE_NAME_RAW="$2"
  FIELD_NAME_RAW="$3"
  NESTED_FIELDS_RAW="$4"
  REPEATED_FLAG="$5"
  CUSTOM_MSG_NAME="$6"

  SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
  PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
  GO_FILE="services/${SERVICE_NAME_LC}.go"
  MODEL_FILE="models/${SERVICE_NAME_LC}.go"

  if [ ! -f "$PROTO_FILE" ]; then
    echo "Proto file not found: $PROTO_FILE" >&2
    exit 1
  fi
  if [ ! -f "$MODEL_FILE" ]; then
    echo "Model file not found: $MODEL_FILE" >&2
    exit 1
  fi

  # Normalize names
  FIELD_NAME_SNAKE="$FIELD_NAME_RAW"
  FIELD_NAME_CAMEL="$(echo "$FIELD_NAME_SNAKE" | awk -F'_' '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) tolower(substr($i,2)) }}1' OFS="")"
  NESTED_MSG_NAME="${CUSTOM_MSG_NAME:-$FIELD_NAME_CAMEL}"

  # Build nested message fields block and detect timestamp usage
  TS_USED=0
  build_nested_block() {
    local RAW="$1"
    local LINES=""
    local NUM=1
    IFS=',' read -ra FL <<< "$RAW"
    for F in "${FL[@]}"; do
      local T="$(echo "$F" | xargs)"; [ -z "$T" ] && continue
      local N=""; local TY=""; local REP=0
      if [[ "$T" == *:* ]]; then
        N="$(echo "$T" | cut -d: -f1 | xargs)"
        TY="$(echo "$T" | cut -d: -f2- | xargs)"
        case "$TY" in
          repeated\ *) REP=1; TY="${TY#repeated }" ;;
          Repeated\ *) REP=1; TY="${TY#Repeated }" ;;
        esac
      else
        echo "Invalid field format in nested: '$T'" >&2; exit 1
      fi
      local TN
      TN="$(normalize_type "$TY")"
      if [ "$TN" = "google.protobuf.Timestamp" ]; then TS_USED=1; fi
      if [ $REP -eq 1 ]; then
        LINES+="  repeated ${TN} ${N} = ${NUM};\n"
      else
        LINES+="  ${TN} ${N} = ${NUM};\n"
      fi
      NUM=$((NUM+1))
    done
    echo -e "$LINES"
  }

  NESTED_BLOCK="$(build_nested_block "$NESTED_FIELDS_RAW")"

  # Ensure timestamp import if needed
  if [ "$TS_USED" -eq 1 ] && ! grep -q 'google/protobuf/timestamp.proto' "$PROTO_FILE"; then
    if grep -q 'import "google/api/annotations.proto";' "$PROTO_FILE"; then
      sed -i '' '/import "google\/api\/annotations.proto";/a\
import "google/protobuf/timestamp.proto";
' "$PROTO_FILE"
    else
      sed -i '' '1,/^package pb;/!b; /^package pb;/a\
\
import "google/protobuf/timestamp.proto";
' "$PROTO_FILE"
    fi
  fi

  # Append nested message before service definition (macOS-safe)
  NESTED_MSG_FILE="$(mktemp)"
  {
    echo "message ${NESTED_MSG_NAME} {"
    echo -e "${NESTED_BLOCK}"
    echo "}"
    echo ""
  } > "$NESTED_MSG_FILE"

  TMP_P="$PROTO_FILE.tmp"
  awk 'FNR==NR{buf=buf $0 "\n"; next} { if (!printed && $0 ~ /^service [A-Za-z0-9_]+Service[ ]*\{/){ printf "%s", buf; printed=1 } print }' "$NESTED_MSG_FILE" "$PROTO_FILE" > "$TMP_P" && mv "$TMP_P" "$PROTO_FILE"
  rm -f "$NESTED_MSG_FILE"

  # Add field to main entity message (message ServiceName { ... }) with next field number
  FIELD_INSERT="${NESTED_MSG_NAME} ${FIELD_NAME_SNAKE}"
  [ "$REPEATED_FLAG" = "repeated" ] && FIELD_INSERT="repeated ${FIELD_INSERT}"

  # Compute next field number in shell (portable)
  MAXN=$(awk -v entity="$SERVICE_NAME" '
    $0 ~ "^message " entity " " {inm=1; next}
    inm==1 && $0 ~ /^}/ { exit }
    inm==1 && $0 ~ /=/ {
      n=$0
      sub(/^.*= */,"",n)
      sub(/;.*/,"",n)
      if (n+0>maxn) maxn=n+0
    }
    END { if (maxn=="") maxn=1; print maxn }
  ' "$PROTO_FILE")
  NEXTN=$((MAXN+1))

  TMP_P2="$PROTO_FILE.tmp"
  awk -v entity="$SERVICE_NAME" -v line="  ${FIELD_INSERT} = ${NEXTN};" '
    $0 ~ "^message " entity " " {print; inm=1; next}
    inm==1 && $0 ~ /^}/ {print line; print; inm=0; next}
    {print}
  ' "$PROTO_FILE" > "$TMP_P2" && mv "$TMP_P2" "$PROTO_FILE"

  echo "Added nested message ${NESTED_MSG_NAME} and field ${FIELD_NAME_SNAKE} to ${PROTO_FILE}"

  # Update model: add nested struct type if not exists and add field to main model struct
  # 1) Append nested struct type at end if missing
  if ! grep -q "type ${NESTED_MSG_NAME} struct" "$MODEL_FILE"; then
    build_go_fields() {
      local RAW="$1"; local LINES=""
      IFS=',' read -ra FL <<< "$RAW"
      for F in "${FL[@]}"; do
        local T="$(echo "$F" | xargs)"; [ -z "$T" ] && continue
        local N=""; local TY=""; local REP=0
        N="$(echo "$T" | cut -d: -f1 | xargs)"
        TY="$(echo "$T" | cut -d: -f2- | xargs)"
        case "$TY" in
          repeated\ *) REP=1; TY="${TY#repeated }" ;;
          Repeated\ *) REP=1; TY="${TY#Repeated }" ;;
        esac
        # normalize type to Go type
        local GO=""; local tn="$(echo "$TY" | tr '[:upper:]' '[:lower:]')"
        case "$tn" in
          string) GO="string";; bool) GO="bool";; bytes) GO="[]byte";; int32) GO="int32";; int64) GO="int64";; float) GO="float32";; double) GO="float64";; google.protobuf.timestamp|timestamp|datetime|date) GO="time.Time";;
          *) GO="string";;
        esac
        if [ $REP -eq 1 ]; then GO="[]$GO"; fi
        local CAM="$(echo "$N" | awk -F'_' '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) tolower(substr($i,2)) }}1' OFS="")" 
        LINES+=$'\t'"${CAM} ${GO} \`json:\"${N}\" bson:\"${N}\"\`\n"
      done
      echo "$LINES"
    }

    GO_FIELDS="$(build_go_fields "$NESTED_FIELDS_RAW")"
    {
      echo ""
      echo "type ${NESTED_MSG_NAME} struct {"
      echo -ne "${GO_FIELDS}"
      echo "}"
    } >> "$MODEL_FILE"
  fi

  # 2) Add field to main model struct if missing (insert before closing brace)
  if ! grep -q "${FIELD_NAME_CAMEL} ${NESTED_MSG_NAME}" "$MODEL_FILE"; then
    TMP_M="$MODEL_FILE.tmp"
    awk -v st="type ${SERVICE_NAME} struct {" -v line="\t${FIELD_NAME_CAMEL} ${NESTED_MSG_NAME} \`json:\\"${FIELD_NAME_SNAKE}\\" bson:\\"${FIELD_NAME_SNAKE}\\"\`" '
      BEGIN{inm=0}
      {
        if ($0 ~ st) { inm=1; print; next }
        if (inm==1 && $0 ~ /^}/) { print line; inm=2 }
        print
      }
    ' "$MODEL_FILE" > "$TMP_M" && mv "$TMP_M" "$MODEL_FILE"
  fi

  echo "Updated model ${MODEL_FILE} with nested struct and field. Please adjust ToProto/FromProto mappings as needed."
  echo "Don't forget to run: make proto"
  exit 0
fi

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 ServiceName \"field1:type1,field2:type2,...\""
  exit 1
fi

SERVICE_NAME_RAW="$1"
FIELDS_RAW="$2"

# PascalCase for service name
SERVICE_NAME="$(echo "$SERVICE_NAME_RAW" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
# lower_snake_case for file name
SERVICE_NAME_LC="$(echo "$SERVICE_NAME_RAW" | tr '[:upper:]' '[:lower:]')"
# Properly pluralized service name for routes and collection names
SERVICE_NAME_PLURAL="$(pluralize "$SERVICE_NAME")"
SERVICE_NAME_LC_PLURAL="$(echo "$SERVICE_NAME_PLURAL" | tr '[:upper:]' '[:lower:]')"
PROTO_FILE="proto/${SERVICE_NAME_LC}.proto"
GO_FILE="services/${SERVICE_NAME_LC}.go"

# Helper to normalize field types
normalize_type() {
  local t="$1"
  local tlc="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  case "$tlc" in
    string|bool|bytes|int32|int64|sint32|sint64|uint32|uint64|fixed32|fixed64|sfixed32|sfixed64|float|double)
      echo "$tlc"
      return 0
      ;;
    timestamp|datetime|date)
      echo "google.protobuf.Timestamp"
      return 0
      ;;
  esac
  # If already fully qualified google.protobuf.Timestamp (any case), standardize casing
  local tlc_lower="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
  if [ "$tlc_lower" = "google.protobuf.timestamp" ]; then
    echo "google.protobuf.Timestamp"
    return 0
  fi
  # Custom message type: ensure PascalCase first letter
  local first="$(echo "${t:0:1}" | tr '[:lower:]' '[:upper:]')"
  echo "${first}${t:1}"
}

# Helper to convert snake_case to camelCase
snake_to_camel() {
  local input="$1"
  local result=""
  local next_upper=false
  
  for ((i=0; i<${#input}; i++)); do
    local char="${input:$i:1}"
    if [ "$char" = "_" ]; then
      next_upper=true
    else
      if [ "$next_upper" = true ]; then
        result+="$(echo "$char" | tr '[:lower:]' '[:upper:]')"
        next_upper=false
      else
        result+="$char"
      fi
    fi
  done
  
  echo "$result"
}

# Pre-process fields to decide imports and build message body
TIMESTAMP_USED=0
FIELD_LINES=""
FIELD_NUM=1
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    # allow 'repeated <type>' after colon
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    # accept 'repeated <type> <name>'
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    else
      echo "Invalid field format: '$RAW_TRIMMED'. Use 'name:type' or 'repeated type name'" >&2
      exit 1
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  if [ "$TYPE_NORM" = "google.protobuf.Timestamp" ]; then
    TIMESTAMP_USED=1
  fi

  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_LINES+="  repeated ${TYPE_NORM} ${NAME} = ${FIELD_NUM};\n"
  else
    FIELD_LINES+="  ${TYPE_NORM} ${NAME} = ${FIELD_NUM};\n"
  fi
  FIELD_NUM=$((FIELD_NUM+1))
done

# Start proto file
echo 'syntax = "proto3";' > "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'package pb;' >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo 'import "google/api/annotations.proto";' >> "$PROTO_FILE"
if [ $TIMESTAMP_USED -eq 1 ]; then
  echo 'import "google/protobuf/timestamp.proto";' >> "$PROTO_FILE"
fi
echo "option go_package = \"${MODULE_PATH}/pb\";" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Message fields
echo "message ${SERVICE_NAME} {" >> "$PROTO_FILE"
echo -e "$FIELD_LINES" >> "$PROTO_FILE"
echo "}" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# CRUD messages
echo "message Create${SERVICE_NAME}Request { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Create${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Get${SERVICE_NAME}Request { string id = 1; }" >> "$PROTO_FILE"
echo "message Get${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Update${SERVICE_NAME}Request { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Update${SERVICE_NAME}Response { ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo "message Delete${SERVICE_NAME}Request { string id = 1; }" >> "$PROTO_FILE"
echo "message Delete${SERVICE_NAME}Response { bool success = 1; }" >> "$PROTO_FILE"
echo "message List${SERVICE_NAME_PLURAL}Request {}" >> "$PROTO_FILE"
echo "message List${SERVICE_NAME_PLURAL}Response { repeated ${SERVICE_NAME} data = 1; }" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"

# Service definition
echo "service ${SERVICE_NAME}Service {" >> "$PROTO_FILE"
echo "  rpc Create${SERVICE_NAME}(Create${SERVICE_NAME}Request) returns (Create${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { post: \"/v1/${SERVICE_NAME_LC_PLURAL}\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Get${SERVICE_NAME}(Get${SERVICE_NAME}Request) returns (Get${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC_PLURAL}/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Update${SERVICE_NAME}(Update${SERVICE_NAME}Request) returns (Update${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { put: \"/v1/${SERVICE_NAME_LC_PLURAL}/{data.id}\" body: \"*\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc Delete${SERVICE_NAME}(Delete${SERVICE_NAME}Request) returns (Delete${SERVICE_NAME}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { delete: \"/v1/${SERVICE_NAME_LC_PLURAL}/{id}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "  rpc List${SERVICE_NAME_PLURAL}(List${SERVICE_NAME_PLURAL}Request) returns (List${SERVICE_NAME_PLURAL}Response) {" >> "$PROTO_FILE"
echo "    option (google.api.http) = { get: \"/v1/${SERVICE_NAME_LC_PLURAL}\" };" >> "$PROTO_FILE"
echo "  }" >> "$PROTO_FILE"
echo "}" >> "$PROTO_FILE"
echo '' >> "$PROTO_FILE"
echo "Created service proto: $PROTO_FILE"

# Generate Go service stub
if [ ! -f "$GO_FILE" ]; then
cat > "$GO_FILE" <<EOF
package services

import (
	"context"
	"${MODULE_PATH}/pb"
)

type ${SERVICE_NAME}Service struct {
	pb.Unimplemented${SERVICE_NAME}ServiceServer
}

func New${SERVICE_NAME}Service() *${SERVICE_NAME}Service {
	return &${SERVICE_NAME}Service{}
}

func (s *${SERVICE_NAME}Service) Create${SERVICE_NAME}(ctx context.Context, req *pb.Create${SERVICE_NAME}Request) (*pb.Create${SERVICE_NAME}Response, error) {
	return &pb.Create${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Get${SERVICE_NAME}(ctx context.Context, req *pb.Get${SERVICE_NAME}Request) (*pb.Get${SERVICE_NAME}Response, error) {
	return &pb.Get${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Update${SERVICE_NAME}(ctx context.Context, req *pb.Update${SERVICE_NAME}Request) (*pb.Update${SERVICE_NAME}Response, error) {
	return &pb.Update${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) Delete${SERVICE_NAME}(ctx context.Context, req *pb.Delete${SERVICE_NAME}Request) (*pb.Delete${SERVICE_NAME}Response, error) {
	return &pb.Delete${SERVICE_NAME}Response{}, nil
}

func (s *${SERVICE_NAME}Service) List${SERVICE_NAME_PLURAL}(ctx context.Context, req *pb.List${SERVICE_NAME_PLURAL}Request) (*pb.List${SERVICE_NAME_PLURAL}Response, error) {
	return &pb.List${SERVICE_NAME_PLURAL}Response{}, nil
}
EOF
  echo "Created Go service stub: $GO_FILE"
else
  echo "Go service stub already exists: $GO_FILE"
fi

# Generate model file
MODEL_FILE="models/${SERVICE_NAME_LC}.go"
if [ ! -f "$MODEL_FILE" ]; then
cat > "$MODEL_FILE" <<EOF
package models

import (
	"time"
	"${MODULE_PATH}/pb"
)

// ${SERVICE_NAME} represents the ${SERVICE_NAME_LC} entity in the database
type ${SERVICE_NAME} struct {
EOF

# Add fields to model struct
FIELD_NUM=1
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Map proto types to Go types
  GO_TYPE=""
  case "$TYPE_NORM" in
    string) GO_TYPE="string" ;;
    int32) GO_TYPE="int32" ;;
    int64) GO_TYPE="int64" ;;
    bool) GO_TYPE="bool" ;;
    float) GO_TYPE="float32" ;;
    double) GO_TYPE="float64" ;;
    bytes) GO_TYPE="[]byte" ;;
    google.protobuf.Timestamp) GO_TYPE="time.Time" ;;
    *) GO_TYPE="string" ;; # Default to string for custom types
  esac
  
  if [ $IS_REPEATED -eq 1 ]; then
    if [ "$GO_TYPE" = "string" ]; then
      GO_TYPE="[]string"
    else
      GO_TYPE="[]$GO_TYPE"
    fi
  fi
  
  # Convert snake_case to camelCase for Go struct field name
  FIELD_NAME="$(snake_to_camel "$NAME")"
  # Ensure first letter is uppercase for exported field (keep camelCase)
  FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  echo "	${FIELD_NAME} ${GO_TYPE} \`json:\"${NAME}\" bson:\"${NAME}\"\`" >> "$MODEL_FILE"
done

cat >> "$MODEL_FILE" <<EOF
}

// New${SERVICE_NAME} creates a new ${SERVICE_NAME} instance with default values
func New${SERVICE_NAME}() *${SERVICE_NAME} {
	return &${SERVICE_NAME}{}
}

// ToProto converts the model to a protobuf message
func (m *${SERVICE_NAME}) ToProto() *pb.${SERVICE_NAME} {
	proto := &pb.${SERVICE_NAME}{
EOF

# Add field mappings for ToProto
FIELD_NUM=1
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Generate field mapping
  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_NAME="$(snake_to_camel "$NAME")"
    FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    echo "		${FIELD_NAME}: m.${FIELD_NAME}," >> "$MODEL_FILE"
  else
    case "$TYPE_NORM" in
      google.protobuf.Timestamp)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: timestamppb.New(m.${FIELD_NAME})," >> "$MODEL_FILE"
        ;;
      *)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: m.${FIELD_NAME}," >> "$MODEL_FILE"
        ;;
    esac
  fi
done

cat >> "$MODEL_FILE" <<EOF
	}
	return proto
}

// FromProto creates a model from a protobuf message
func ${SERVICE_NAME}FromProto(p *pb.${SERVICE_NAME}) *${SERVICE_NAME} {
	if p == nil {
		return nil
	}
	
	m := &${SERVICE_NAME}{
EOF

# Add field mappings for FromProto
FIELD_NUM=1
IFS=',' read -ra FIELDS <<< "$FIELDS_RAW"
for FIELD in "${FIELDS[@]}"; do
  RAW_TRIMMED="$(echo "$FIELD" | xargs)"
  [ -z "$RAW_TRIMMED" ] && continue

  NAME=""
  TYPE_RAW=""
  IS_REPEATED=0

  if [[ "$RAW_TRIMMED" == *:* ]]; then
    NAME="$(echo "$RAW_TRIMMED" | cut -d: -f1 | xargs)"
    TYPE_RAW="$(echo "$RAW_TRIMMED" | cut -d: -f2- | xargs)"
    case "$TYPE_RAW" in
      repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#repeated }"
        ;;
      Repeated\ *)
        IS_REPEATED=1
        TYPE_RAW="${TYPE_RAW#Repeated }"
        ;;
    esac
  else
    if [[ "$RAW_TRIMMED" =~ ^[Rr]epeated[[:space:]]+([^[:space:]]+)[[:space:]]+([a-z][A-Za-z0-9_]*)$ ]]; then
      IS_REPEATED=1
      TYPE_RAW="${BASH_REMATCH[1]}"
      NAME="${BASH_REMATCH[2]}"
    fi
  fi

  TYPE_NORM="$(normalize_type "$TYPE_RAW")"
  
  # Generate field mapping
  if [ $IS_REPEATED -eq 1 ]; then
    FIELD_NAME="$(snake_to_camel "$NAME")"
    FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    echo "		${FIELD_NAME}: p.${FIELD_NAME}," >> "$MODEL_FILE"
  else
    case "$TYPE_NORM" in
      google.protobuf.Timestamp)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: p.Get${FIELD_NAME}().AsTime()," >> "$MODEL_FILE"
        ;;
      *)
        FIELD_NAME="$(snake_to_camel "$NAME")"
        FIELD_NAME="$(echo "$FIELD_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        echo "		${FIELD_NAME}: p.${FIELD_NAME}," >> "$MODEL_FILE"
        ;;
    esac
  fi
done

cat >> "$MODEL_FILE" <<EOF
	}
	
	return m
}

// CollectionName returns the MongoDB collection name for this model
func (${SERVICE_NAME}) CollectionName() string {
	return "${SERVICE_NAME_LC_PLURAL}"
}
EOF
  echo "Created model file: $MODEL_FILE"
else
  echo "Model file already exists: $MODEL_FILE"
fi

# Register in server/grpc.go
GRPC_GO="server/grpc.go"
GRPC_REG="pb.Register${SERVICE_NAME}ServiceServer(grpcServer, services.New${SERVICE_NAME}Service())"
grep -q "$GRPC_REG" "$GRPC_GO" || \
  sed -i '' "/grpcServer := grpc.NewServer()/a\\
$GRPC_REG
" "$GRPC_GO"

# Register in server/gateway.go
GATEWAY_GO="server/gateway.go"
GATEWAY_REG="pb.Register${SERVICE_NAME}ServiceHandler(ctx, mux, conn)"
grep -q "$GATEWAY_REG" "$GATEWAY_GO" || \
  sed -i '' "/defer conn.Close()/a\\
\\
	if err = $GATEWAY_REG; err != nil {\\
		return err\\
	}\\
" "$GATEWAY_GO"

echo "Don't forget to run: make proto"
echo "Service registered in $GRPC_GO and $GATEWAY_GO"
echo "Implement your business logic in $GO_FILE" 