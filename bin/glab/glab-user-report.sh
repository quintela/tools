#!/usr/bin/env bash

validate_param() {
  if [ -z "$1" ]; then
    if [ "$3" = true ] ; then
      echo "$2 has not been specified."
      exit 1
    fi
  fi
}


while test $# -gt 0; do
  case "$1" in
    -s)
      shift
      if test $# -gt 0; then
        export first_date=$1
      else
        echo "No first_date specified"
        exit 1
      fi
      shift
      ;;
    --start*)
      export first_date=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -e)
      shift
      if test $# -gt 0; then
        export last_date=$1
      else
        echo "No last_date specified"
        exit 1
      fi
      shift
      ;;
    --end*)
      export last_date=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -d)
      shift
      if test $# -gt 0; then
        export glab_domain=$1
      else
        echo "No user specified"
        exit 1
      fi
      shift
      ;;
    --domain*)
      export glab_domain=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -u)
      shift
      if test $# -gt 0; then
        export user=$1
      else
        echo "No user specified"
        exit 1
      fi
      shift
      ;;
    --user*)
      export user=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    -p)
      shift
      if test $# -gt 0; then
        export SECRET_PATH=$1
      else
        echo "No path to secret file specified"
        exit 1
      fi
      shift
      ;;
    --path*)
      export SECRET_PATH=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    *)
      break
      ;;
  esac
done

validate_param "$user" "user (-u|--user=)"
validate_param "$glab_domain" "domain (-d|--domain=)"
validate_param "$first_date" "first_date (-s|--start=)"
validate_param "$last_date" "last_date (-e|--end=)"
validate_param "$SECRET_PATH" "secret path (-p|--path=)"

# defaults
if [ -z $SECRET_PATH ]; then
  export SECRET_PATH=${2:-$HOME/.pwd/glab.pwd}
else
  if [ ! -f $SECRET_PATH ]; then
    echo "secret path $SECRET_PATH not found"
    exit 1
  fi
  export SECRET_PATH=$SECRET_PATH
fi
if [ -z $first_date ]; then
  last_month_year=$(date +'%m %Y' | awk '!--$1{$1=12;$2--}1')
  lm=${last_month_year% *}
  ly=${last_month_year##* }
  ld=$(cal $lm $ly | paste -s - | awk '{print $NF}')
  export first_date=$(printf '%s-%02s-%s' $ld $lm $ly)
fi
if [ -z $last_date ]; then
  month_year=$(date +'%m %Y' | awk '!$1{$1=12;$2--}1')
  m=${month_year% *}
  y=${month_year##* }
  d=$(cal $m $y | paste -s - | awk '{print $NF}')
  export last_date=$(printf '%s-%02s-%s' $d $m $y)
fi
if [ -z $user ]; then
  export user=2
fi

# setup PAT token
export GITLBAPAT=$(cat $SECRET_PATH)
GITLAB_AUTH_HEADER="PRIVATE-TOKEN: $GITLBAPAT"

echo "Getting data from user $user from $first_date to $last_date"

page=1

while true; do
  URL="https://$glab_domain/api/v4/users/$user/events?per_page=100&after=$first_date&before=$last_date&page=$page&sort=asc"

  curl -s -f -H "$GITLAB_AUTH_HEADER" $URL > result.json

  size=$(cat result.json | jq '. | length')

  cat result.json | jq -r '(.[] | [.created_at, .action_name, .push_data.commit_title, .push_data.ref, .target_title]) | @csv' \
    | sed 's/"//g' | sed 's/,/ /g' | sed 's/:[0-9][0-9]\.[0-9][0-9][0-9]Z//g' | sed -E 's/([0-9])T([0-9])/\1 \2/g' | tr -s ' '

  rm result.json
  if [[ "$size" -gt "0" ]]; then
    page=$((page+1))
  else
    break
  fi
done
