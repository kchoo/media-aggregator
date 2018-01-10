# media-aggregator

Application for collecting media from various sources (twitter, discord, etc.)

## About

I want to collect media from various sources, with scheduled AWS Lambda functions pulling most recent media from each source regularly, and storing them (in case they get deleted from the source). There will be a site where users will be able to view images, upvote/downvote, and add tags. Tags will allow you to filter images, but with potentially millions of images, it's not feasible for me to add all tags myself, so I'm going to outsource that to the users: there will be a point system on the site where you pay points for viewing images, and gain points for voting and tagging images. There will be a QA process to make sure these tags are accurate, and users not adhering to this will be banned. The end goal is to create a large training set of images with tags, then use machine learning to automate the tagging process. I'm hoping to also keep track of the best images to have a "high scoring images" section on the site, and filter out poor-performing images automatically

## Architecture

