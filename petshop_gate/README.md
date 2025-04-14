# Petshop Gate

## Challenge type

Exploitation (pow)

## Vulnerabilities

Nosql injection to get `flag` stored in Redis.

```python
        # this is where the format is leaked
        sys.stdout.write(f"[.] Requested {pow_key}.\r")
```

The `\r` at the end of the line means that this line of output will be overwritten by the next line of output.
So players are likely to miss it if they do not dump the output to a file.

