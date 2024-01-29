#!/usr/bin/env fish

source .env
mix deps.get
cd assets
npm install
cd ..
mix assets.deploy
mix release
