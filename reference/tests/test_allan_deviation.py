import pytest
import numpy as np
from reference.allan_deviation import compute_allan_deviation


def test_allan_deviation_white_noise_slope():
    """
    Untuk white noise murni, kemiringan kurva log-log Allan deviation adalah -0.5
    (sigma(tau) proporsional terhadap 1 / sqrt(tau)).
    """
    np.random.seed(42)
    rate_hz = 50.0
    # 5000 sampel white noise dengan std dev 200 nT
    noise = np.random.normal(loc=45000.0, scale=200.0, size=5000).tolist()

    res = compute_allan_deviation(noise, rate_hz=rate_hz, num_tau=15)

    assert len(res["tau_s"]) > 5
    assert len(res["adev"]) == len(res["tau_s"])
    assert res["noise_floor"] > 0.0
    # Tau pertama (m=1) adev harus mendekati sigma / sqrt(2) * sqrt(2) ~ sigma
    assert 150.0 < res["adev"][0] < 250.0

    # Dengan averaging cluster lebih besar, adev harus turun
    assert res["adev"][-1] < res["adev"][0]


def test_allan_deviation_too_few_samples():
    with pytest.raises(ValueError, match="terlalu sedikit"):
        compute_allan_deviation([10.0, 20.0, 30.0], rate_hz=50.0)


def test_allan_deviation_constant_signal():
    """Sinyal konstan sempurna tanpa noise harus memiliki Allan deviation 0."""
    values = [45000.0] * 100
    res = compute_allan_deviation(values, rate_hz=50.0)
    assert res["noise_floor"] == 0.0
    for a in res["adev"]:
        assert a == 0.0
