#!/usr/bin/env bash

commit_message=
while getopts ':m:' opt
do
    case $opt in
        m)
        commit_message=$OPTARG
        ;;
        ?)
        echo "未知参数"
        exit 1;;
    esac
done

hexo clean
hexo g
hexo d

echo ${commit_message}
git add .
git commit -m "${commit_message}"
git push origin hexo
