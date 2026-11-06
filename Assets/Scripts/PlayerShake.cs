using System.Collections;
using UnityEngine;

public class PlayerShake : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    [Header("References")]
    public float timeToShake;
    public float shakeStrenght;
    private Transform _trackingSpace;
    private Vector3 _orginalLocalPosition;

    private void Awake()
    {
        _trackingSpace = GetComponent<Transform>();
    }

    public void StartShakePlayer()
    {
        StartCoroutine(ShakePlayer(timeToShake, shakeStrenght));
    }

    private IEnumerator ShakePlayer(float duration,float magnitud)
    {
        Vector3 trackOriginalPosition = _trackingSpace.localPosition;
        float time = 0f;

        while (time<=duration)
        {
            Vector3 randomOffset = Random.insideUnitSphere * magnitud;

            _trackingSpace.localPosition = _trackingSpace.localPosition + randomOffset;
            
            yield return null;
        }
    }
    
}
