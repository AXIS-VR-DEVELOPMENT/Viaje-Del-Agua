using UnityEngine;
using System.Collections;

public class AnfinaveMenuScript : MonoBehaviour
{
    private float _time = 15f;
    private float _speed;
    private Transform _naveTransform;
    
    void Awake()
    {
        _naveTransform = transform; 
    }

    void Start()
    {
        
        StartCoroutine(StartNaveAnimation());
    }

    void Update()
    {
        
        RotateNave(_speed);
    }

    private void RotateNave(float velocity)
    {
        _naveTransform.Rotate(0f, -velocity * Time.deltaTime, 0f);
    }

    private IEnumerator StartNaveAnimation()
    {
        WaitForSeconds interval = new WaitForSeconds(_time);
        
        while (true)
        {
            // Se asigna la velocidad primero para que no empiece en 0
            _speed = Random.Range(10f, 20f);
            yield return interval;
        }
    }
}