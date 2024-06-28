| spending_by_category          | coupon      | gets_free_shipping? |
|-------------------------------|-------------|---------------------|
| %{shoes: 19_99, pants: 29_99} |             | false               |
| %{shoes: 59_99, pants: 49_99} |             | true                |
| %{socks: 10_99}               |             | true                |
| %{shoes: 19_99}               | "FREE_SHIP" | true                |
