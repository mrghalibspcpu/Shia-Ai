Bundled SQLite books are unpacked here before a Flutter build:

```sh
python3 scripts/prepare_databases.py --output app/assets/databases
```

The expanded `*.db` files are gitignored. The compressed source remains `assets/shia-databases.zip`.
