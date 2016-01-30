{
  "targets": [
    {
      "target_name": "batterystatus",
      "sources": ["index.cc"],
      "include_dirs": [
        "<!(node -e \"require('nan')\")"
      ]
    }
  ]
}
