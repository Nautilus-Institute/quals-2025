# Petshop

## Challenge type

Web (flag 1) / Exploitation (flag 2, 3)

## Description

### Petshop 1

```
Dear customer, we appreciate your patience at the gate. Now please enjoy our
world-class pet listing and adoption service developed using the latest Web 4.0
and the newest data transmission technologies. We sincerely wish you a great
experience at our shop!

Unfortunately, our customer support only works on Mondays and Fridays, so our
pet shop is unattended today. Do not let your pets read `/flag` because there is
nothing interesting there (unless they read octets).

`nc petshop-rc6ocl7rn7o6g.shellweplayaga.me 1337`
```

### Petshop 2

```
Dear customer, we are very upset at what your pets did earlier today. But we
still appreciate your business. So please find a reward for your beloved pet
somewhere in our shop.

This time it is no longer a file or anything on the file system.

... how about dumping the entire service?

`nc petshop-rc6ocl7rn7o6g.shellweplayaga.me 1337`
```

### Petshop 3

```
Dear customer, have you said thank you once to our hard-working clerks? We
tried so hard creating a beautiful and welcoming pet shop for you, but you
keep ruining it!

However, we still appreciate your service, and we are offering a special
discount for you and your pet. The discount code is located at `/flag_XXXX`,
where `XXXX` is a unique random token that you will know when you see it.

Oh we almost forgot: our pet shop just moved!

`nc petshop-rc6ocl7rn7o6g.shellweplayaga.me 3337`
```


## Vulnerabilities

- When updating the pet name, even invalid pet name is kept (bu the pet is immediately delisted).
- Delisted pets can still be selected!
- Description loading (when pet description is stored on the file system) allows directory traversal.
- Image name is extracted from the URL.
- Existing images are not overwritten, but the image path will be updated in Pet.image_path.
- The IPP implementation includes a backdoor (`printer-is-diagnostic`) that allows file listing of at least "/".

## Getting flags

1. Flag 1 (`/flag`)

- Register a pet; give it a long description so it's stored on the file system.
- Register a printer.
- Update the pet name to include `../../../flag`.
- Print the pet and profit.

2. Flag 2 (inside the executable)

`flag{8_8_international_cat_day_751D5A377DE22F72D3CECD3D0715D6FE}`

- The binary can be leaked by printing the `petshop` binary as a pet picture to a registered printer.
- Reverse the leaked binary to retrieve the second flag.

3. Flag 3 (`/flag_XXXXXXXXXXXX` where `XXXXXXXXXXXXX` is a random token, randomized for each connection)

- Use the backdoor in the IPP implementation to list `/`, find the special flag file (the file name is randomized each time).
- Read it out the same way as reading flag 1.
