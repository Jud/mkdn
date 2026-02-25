# The Gaussian Integral

One of the most elegant results in analysis connects probability, geometry, and calculus through a single integral:

$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$

This result is remarkable -- the area under the bell curve $e^{-x^2}$ involves $\pi$, a constant from geometry, despite the integrand having no obvious connection to circles.

## Proof via Polar Coordinates

Let $I = \int_{-\infty}^{\infty} e^{-x^2} dx$. Then:

$$I^2 = \int_{-\infty}^{\infty} e^{-x^2} dx \int_{-\infty}^{\infty} e^{-y^2} dy = \int_{-\infty}^{\infty}\int_{-\infty}^{\infty} e^{-(x^2+y^2)} \, dx \, dy$$

Switching to polar coordinates where $x^2 + y^2 = r^2$:

$$I^2 = \int_0^{2\pi}\int_0^{\infty} e^{-r^2} \, r \, dr \, d\theta = 2\pi \cdot \frac{1}{2} = \pi$$

Therefore $I = \sqrt{\pi}$.

## Connection to Probability

The **normal distribution** with mean $\mu$ and variance $\sigma^2$ has density:

$$f(x) = \frac{1}{\sigma\sqrt{2\pi}} \, e^{-\frac{(x-\mu)^2}{2\sigma^2}}$$

The normalization factor $\frac{1}{\sigma\sqrt{2\pi}}$ ensures $\int_{-\infty}^{\infty} f(x) \, dx = 1$, which follows directly from the Gaussian integral.

### Key Properties

- **Expected value**: $E[X] = \mu$
- **Variance**: $\text{Var}(X) = \sigma^2$
- **Moment generating function**: $M(t) = e^{\mu t + \frac{1}{2}\sigma^2 t^2}$
- **68-95-99.7 rule**: $P(\mu - k\sigma \leq X \leq \mu + k\sigma)$ for $k = 1, 2, 3$

## Euler's Identity

> Perhaps the most beautiful equation in all of mathematics connects five fundamental constants in a single expression:
>
> $$e^{i\pi} + 1 = 0$$
>
> It unites the additive identity ($0$), the multiplicative identity ($1$), the base of natural logarithms ($e$), the ratio of circumference to diameter ($\pi$), and the imaginary unit ($i$).

## The Riemann Zeta Function

For $\text{Re}(s) > 1$, the zeta function is defined as:

$$\zeta(s) = \sum_{n=1}^{\infty} \frac{1}{n^s} = \prod_{p \text{ prime}} \frac{1}{1 - p^{-s}}$$

The equality between the sum and the product (Euler's product formula) encodes the fundamental theorem of arithmetic.

Some notable values: $\zeta(2) = \frac{\pi^2}{6}$, $\zeta(4) = \frac{\pi^4}{90}$, and the famous conjecture concerns $\zeta(s) = 0$ for $\text{Re}(s) = \frac{1}{2}$.
