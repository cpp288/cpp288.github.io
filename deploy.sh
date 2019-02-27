#!/bin/sh

commit_message=
while getopts ':m:' opt
do
    case $opt in
        m)
        commit_message=$OPTARG
        ;;
        ?)
        echo "Usage: args [-m]"
        echo "-m means git commit message"
        exit 1
        ;;
    esac
done

if [[ ! ${commit_message} ]]; then
    echo "git提交注释不能为空，使用 -m \"commit message\""
    exit 1
fi

hexo clean
hexo g
hexo d

echo ${commit_message}
git add .
git commit -m "${commit_message}"
git push origin hexo
